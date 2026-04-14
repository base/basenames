# Soul-Bound Promotion Plan for Basenames

**Steve Katzman** | March 25, 2026

## Problem Statement

Existing Basenames have four properties that are undesirable for a long-lived permanent identity:

1. **They expire** -- `nameExpires[id]` is a finite timestamp; after expiry + grace, the name is released. Users must continually renew or risk losing their identity.

2. **They are transferable** -- standard ERC721 transfer mechanics allow anyone to `transferFrom`. An identity primitive should be bound to its holder.

3. **A name cannot be changed after the fact** -- the label is baked into the token ID (`keccak256(label)`). There's no way for a user to evolve their display identity without registering an entirely new name.

4. **No protection against impersonation** -- anyone can register a name resembling a real person or brand (e.g., `elonmusk.base.eth`). Once registered, there is no admin mechanism to reclaim it on behalf of the legitimate claimant. If names become permanent and non-transferable without such a mechanism, impersonators gain irrevocable ownership.

We need a solution that:

- Works for **existing** names (opt-in by token holders) as well as fresh registrations.

- Provides **protocol-level** guarantees (not just application-layer conventions).

- Includes **admin safeguards** against impersonation and abuse.

- Requires **no changes** to `BaseRegistrar`, `Registry`, or other immutable contracts.

## Design Principles

- **Minimal tear-up**: No modifications to immutable contracts avoiding complex migrations.
- **Opt-in**: Existing name holders choose to promote their name. Unpromoted names behave exactly as they do today.
- **Protocol-level enforcement**: Non-transferability and non-expiry are enforced on-chain, not by front-end convention.
- **Admin reclamation**: Protocol operators retain the ability to reclaim names from bad actors or impersonators, mirroring the moderation model of web2 identity platforms (Twitter, Facebook, etc.). Permanence applies to good-faith holders; it does not grant squatters or impersonators irrevocable ownership.
- **Leverage existing extension points**: `BaseRegistrar.addController(address)` grants the wrapper `renew` access. `UpgradeableL2Resolver.setControllerApproval` grants resolver record access. No new permissions models are needed.
- **ENS specification compliance**: Promoted names must remain resolvable via standard ENS interfaces (ENSIP-1 through ENSIP-19), CCIP-read (ERC-3668/ENSIP-10) must continue to work for L1 resolution, and reverse resolution must behave identically to unpromoted names. Any ENS-speaking client should resolve a promoted name without awareness of the wrapper.

---

## Architecture: `SoulboundNameWrapper`

A single new contract that acts as both a **controller** on `BaseRegistrar` and an **ERC721** (soul-bound) token issuer. It custodies the underlying `BaseRegistrar` NFTs, issues non-transferable wrapper tokens to users, and provides admin hooks for moderation.

### How It Works

```
                           ┌───────────────────────────────┐
                           │    SoulboundNameWrapper       │
                           │                               │
   User calls              │  - ERC721 (soul-bound)        │
   wrap(id) ──────────────>│  - IERC721Receiver            │
                           │  - Controller on BaseRegistrar│
                           │  - AccessControl (roles)      │
                           │                               │
                           │  Holds underlying NFTs        │
                           │  Issues non-transferable      │
                           │  wrapper tokens               │
                           └────────┬──────────────────────┘
                                    │
              ┌─────────────────────┼─────────────────────┐
              │                     │                     │
              ▼                     ▼                     ▼
     BaseRegistrar            ENS Registry          L2 Resolver
     (NFT custodied           (subnode owner        (records set
      by wrapper)              set to user)          by user or
                                                     wrapper)
```

### Wrap Flow (Existing Names)

An existing name holder opts in by approving and wrapping:

1. **User approves** the wrapper to transfer their Basename NFT.
2. **User calls `wrap(id)`** on the `SoulboundNameWrapper`.
3. The wrapper atomically:
   - **Takes custody of the underlying Basename** via `safeTransferFrom`. The wrapper now holds the ERC721 token.
   - **Extends expiry to permanent** by calling `BaseRegistrar.renew(id, ...)` to push `nameExpires[id]` to effectively infinity.
   - **Restores ENS Registry ownership to the user** via `BaseRegistrar.reclaim(id, user)`, ensuring the user retains full control over their resolver records.
   - **Mints a soul-bound wrapper token** (same `id`) to the user. This token is non-transferable (possible EIP-5192 compliance).
   - **Sets promotion metadata** on the resolver via multicall (e.g., `basenames.promoted` text record and the ENSIP-18 `alias` text record).

### Fresh Registration Flow

For names that don't exist yet, the wrapper can also handle first-time registration:

1. **User calls `registerAndWrap(name, resolver, data)`**.
2. The wrapper registers the name with itself as the `BaseRegistrar` NFT owner, permanent duration, then follows the same `reclaim` + mint + metadata steps as the wrap flow.

Business logic around pricing/discounting can be determined in a separate exploration.

---

## Objective 1: Non-Expiring Names

### Mechanism

The wrapper, as an approved controller, calls `BaseRegistrar.renew(id, duration)` where `duration` is computed to push `nameExpires[id]` to a value no `block.timestamp` will ever reach (effectively `type(uint256).max`).

The key interactions with `BaseRegistrar`:

- **`isAvailable(id)`** evaluates `nameExpires[id] + GRACE_PERIOD < block.timestamp` -- with a near-max expiry, this is never true. The name can never appear available for re-registration.
- **`ownerOf(id)`** checks `nameExpires[id] <= block.timestamp` -- never true. The token never appears expired.
- **`renew` preconditions**: The name must still be active or within its grace period at wrap time. Users must wrap **before** their grace period ends; lapsed names would need to be re-registered fresh via `registerAndWrap`.

**Edge case note**: Setting expiry to exactly `type(uint256).max` causes `isAvailable` to overflow in Solidity 0.8+ (revert, not wrap-around), which is safe but inelegant. Using `type(uint256).max - GRACE_PERIOD - 1` avoids this cleanly. The exact value is an implementation detail to validate in testing.

### Trade-offs

| Consideration | Impact |
|---|---|
| **Permanent occupation** | The name is taken for the lifetime of the protocol. If the holder loses their keys, admin reclamation (see below) provides a recovery path. Without admin action, the name sits occupied by an inaccessible address. |
| **No renewal revenue** | Promoted names generate zero ongoing fees. |
| **Grace period deadline** | Existing holders must wrap before their name lapses past grace. Communication and UX need to make this clear. |

---

## Objective 2: Non-Transferable (Soul-Bound)

### Mechanism

The `SoulboundNameWrapper` is itself an ERC721 contract whose tokens **cannot be transferred by the holder**:

1. **Transfer functions revert** -- `transferFrom` and `safeTransferFrom` revert unconditionally for all wrapper tokens.
2. **Underlying NFT is custodied** -- The `BaseRegistrar` token sits in the wrapper contract. The user has no access to transfer it.

The **sole exception** to non-transferability is **admin reclamation**: protocol operators with the `RECLAIMER_ROLE` can reassign a wrapped name to a different address (see Admin Reclamation section). This is an intentional carve-out for moderation and recovery, not a general transfer mechanism.

### Why This Is Protocol-Level

- The wrapper **custodies** the underlying NFT. The user cannot call `transferFrom` on `BaseRegistrar` because they are not the owner or approved.
- The wrapper **never exposes** a code path that moves the underlying NFT to another address.
- The wrapper's own ERC721 tokens revert on transfer.
- No application-layer trust is required for the non-transferability guarantee -- it is enforced entirely in smart contract logic. The admin reclamation path is the only override, and it is role-gated on-chain.

### Registry Ownership

After wrapping, the ENS Registry subnode owner is the **user** (via `reclaim`). This means:

- The user retains full control over resolver records (`setText`, `setAddr`, etc.).
- The user can change their resolver via `registry.setResolver(node, newResolver)`.
- The user **cannot** re-register or transfer the underlying name -- the `BaseRegistrar` NFT is custodied by the wrapper.
- Admin reclamation can reassign Registry subnode ownership to a new address if needed.

### Trade-offs

| Consideration | Impact |
|---|---|
| **Key loss** | If a user loses access to their address, the wrapper token is inaccessible. Admin reclamation provides a recovery path: the user proves identity off-chain, the admin reassigns to a new address. Without admin action, the name remains occupied. |
| **Marketplace compatibility** | EIP-5192 is supported by Opensea. Non-compliant marketplaces may still display the token but transfer attempts will revert on-chain. |
| **Admin trust** | The soul-bound guarantee has an admin exception. Users must trust our operator's moderation policy. |

---

## Objective 3: Changeable Display Name

### Mechanism

The label (e.g., "alice" in `alice.base.eth`) is immutable -- it's `keccak256(label)`, baked into the token ID. We layer a **mutable display name** on top using the **`alias` text record** defined in [ENSIP-18: Profile Text Records](https://docs.ens.domains/ensip/18).

ENSIP-18 standardizes `alias` as a display alias for ENS names. The spec states it should be displayed near the ENS name but not as a replacement, and should sit below the name in visual hierarchy. This is exactly the semantics we want -- no need for a custom `basenames.display` key.

1. **Text record key**: `"alias"` (ENSIP-18 standard).
2. During wrap, the wrapper sets `setText(node, "alias", label)` as a sensible default.
3. The **user can update it at any time** by calling `setText(node, "alias", "New Name")` on the resolver. This works today: the user is the Registry owner of the node and passes the resolver's authorization check.
4. The **front-end** resolves display names by checking `text(node, "alias")` first, falling back to the on-chain label if unset. Per ENSIP-18, apps should also check the legacy `name` text key as a fallback if `alias` is not set.

Using the ENSIP-18 standard means any ENS-aware app that supports profile text records will display the alias automatically, not just the Basenames front-end.

### Reverse Resolution

Reverse resolution (address -> name) is a separate mechanism via ENSIP-19. A user's primary name and their alias text record are independent -- the primary name controls ENS reverse resolution, while the alias is a cosmetic overlay for UIs that support ENSIP-18 profiles.

### Trade-offs

| Consideration | Impact |
|---|---|
| **No uniqueness** | Aliases are cosmetic. Two users can set the same alias. The `.base.eth` name remains the unique identifier. |
| **No content validation** | Aliases are arbitrary strings (per ENSIP-18: "any text"). Content moderation would happen at the front-end or API layer. |
| **Cheap to update** | `setText` on Base L2 costs fractions of a cent. Low barrier to experimentation. |
| **Ecosystem compatibility** | Any ENS app supporting ENSIP-18 will display the alias without Basenames-specific integration. |

---

## Objective 4: Impersonation Mitigation via Admin Reclamation

### Motivation

Permanence and non-transferability are the core value proposition, but they also raise the stakes on impersonation and abuse. If a bad actor wraps `brianarmstrong.base.eth`, that name is locked forever with no recourse unless the protocol has a moderation mechanism.

Web2 identity platforms solve this with admin moderation. The wrapper provides an on-chain equivalent, allowing a permissioned operator to act on behalf of legitimate claimants while maintaining a transparent audit trail.

Admin reclamation also serves as a **key loss recovery mechanism**: a user who loses access to their wallet can prove their identity off-chain, and the admin can reassign the name to a new address.

### What Reclamation Does NOT Do

- It does **not** move the underlying `BaseRegistrar` NFT -- that stays in the wrapper permanently.
- It does **not** change the name's permanent expiry -- the name remains non-expiring.
- It does **not** affect other wrapped names -- reclamation is strictly per-name.

### Trade-offs

| Consideration | Impact |
|---|---|
| **Trust in admin** | Users accept that the soul-bound guarantee has an admin exception. This is identical to how web2 platforms operate. Multi-sig + audit trail + optional timelock mitigate abuse risk. |
| **Policy dependency** | The smart contract provides the *capability*; a separate policy document must define *when* reclamation is appropriate (impersonation, trademark, court order, key recovery, etc.). The contract is intentionally policy-agnostic. |
| **Reclamation as recovery** | Using the same mechanism for moderation and key-loss recovery is pragmatic but blurs two distinct use cases. Consider whether recovery should have a separate flow with different approval requirements (e.g., higher multi-sig threshold or identity verification). |

---

## End-to-End Ownership Model After Wrapping

| Layer | Owner | Implication |
|---|---|---|
| `BaseRegistrar` ERC721 | `SoulboundNameWrapper` contract | Custodied permanently. Cannot be transferred out. Non-expiring. |
| ENS `Registry` subnode | User's address (via `reclaim`) | User controls resolver and all records. Admin can reassign via reclamation. |
| `SoulboundNameWrapper` ERC721 | User's address | Soul-bound to user. Cannot be transferred. Admin can reassign via reclamation. |
| Resolver records | User (authorized as Registry owner) | User can `setText`, `setAddr`, etc. freely. Admin can clear during reclamation. |
| Reverse record | User (via `ReverseRegistrar`) | User controls their primary name. |

---

## Summary of Guarantees

| Property | Mechanism | Guarantee Level |
|---|---|---|
| **Non-expiring** | `renew` to near-max expiry via controller access | Protocol-level. No `block.timestamp` will ever exceed the expiry. |
| **Non-transferable** | Wrapper custodies underlying NFT; wrapper tokens revert on transfer; EIP-5192 | Protocol-level. No user-initiated transfer path exists. Admin reclamation is the sole exception. |
| **Admin reclamation** | `RECLAIMER_ROLE` can reassign or revoke names | Protocol-level. Role-gated, auditable, optionally timelocked. |
| **Changeable display** | ENSIP-18 `alias` text record set by user on resolver | ENS standard (ENSIP-18). User has full on-chain control. Compatible with any ENSIP-18-aware app. |

---

## Areas to Explore Further

1. **Unwrap path**: Should users be able to unwrap (revert to a normal transferable name)? If so, the permanent expiry cannot be undone (`renew` only extends), so the name stays non-expiring. An unwrap path weakens the identity guarantee but adds user flexibility. Is there a middle ground -- e.g., unwrap with a cooldown or admin approval? Most important open question since this changes how we approach non-expiry.

2. **Pricing model**: Is wrapping free? One-time fee? Should `registerAndWrap` mirror normal registration pricing, or is it a separate promotional price tier? How does this interact with the existing discount system?

3. **Eligibility gating**: Should anyone be able to wrap, or only addresses that meet criteria (allowlist, attestation, on-chain activity threshold)? The existing `IDiscountValidator` pattern could be reused. For early rollout, admin-only or allowlisted wrapping may be preferable.

4. **Reclamation policy framework**: The contract is intentionally policy-agnostic. A separate governance document should define when reclamation is appropriate: impersonation, trademark disputes, court orders, key-loss recovery. Different categories may warrant different approval thresholds (e.g., impersonation = standard multi-sig, key recovery = higher threshold + identity proof).

7. **Token metadata and visual identity**: Should promoted names have distinct metadata, artwork, or badge indicators in the wrapper token's `tokenURI`? This could help wallets and UIs visually distinguish promoted identities from standard names.

8. **Subgraph and indexer impact**: Existing subgraphs index `BaseRegistrar` Transfer/NameRegistered events. Wrapped names will appear as owned by the wrapper contract at the `BaseRegistrar` level. Indexers and front-ends that rely on `BaseRegistrar.ownerOf` will need to understand the wrapper layer. Explore whether the wrapper should emit compatible events or if a dedicated subgraph is more appropriate.

10. **Progressive decentralization of admin**: Over time, the `RECLAIMER_ROLE` could transition from a team-operated multi-sig to a community governance process (e.g., on-chain dispute resolution DAO). The `AccessControl` pattern supports this by allowing role reassignment without contract changes.
