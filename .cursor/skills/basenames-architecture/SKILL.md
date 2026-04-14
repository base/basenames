---
name: basenames-architecture
description: >-
  Architecture reference for the Basenames ENS-on-Base smart contract system.
  Use when working with Basenames contracts, understanding the registration flow,
  resolver records, pricing, discounts, transfer mechanics, or name lifecycle.
---

# Basenames Architecture

Basenames is a Foundry-based Solidity project that implements ENS-style naming on Base L2. It manages `*.base.eth` subdomains via an ERC721 registrar, pluggable controllers, and ENS-compatible resolvers.

## Repository Layout

| Path | Role |
|------|------|
| `src/L2/` | Core L2 contracts (registrar, controllers, resolvers, oracles, discounts) |
| `src/L1/` | L1 CCIP-read resolver for `base.eth` on Ethereum mainnet |
| `src/lib/` | Shared libraries (EDA pricing math, hashing, signature verification) |
| `src/util/Constants.sol` | Shared constants (`BASE_ETH_NODE`, `GRACE_PERIOD = 90 days`, etc.) |
| `test/` | Forge tests (~193 files), `test/mocks/` for test doubles |
| `script/` | Deployment and configuration scripts |
| `lib/` | Vendored deps (ens-contracts, forge-std, OpenZeppelin, Solady, EAS) |

## Core Contract Map

For detailed contract analysis, see [contracts.md](contracts.md).

### Registration Stack

```
User
  |
  v
RegistrarController / UpgradeableRegistrarController (URC)
  |  - validates name, duration, payment
  |  - applies discounts via IDiscountValidator
  |  - calls BaseRegistrar.registerWithRecord()
  |  - optionally sets resolver records via multicall
  |  - optionally sets reverse record
  v
BaseRegistrar (ERC721 + ENS subnode owner)
  |  - mints NFT token (id = uint256(keccak256(label)))
  |  - sets nameExpires[id] = block.timestamp + duration
  |  - writes to ENS Registry
  v
Registry (ENS-compatible)
  |  - stores node -> { owner, resolver, ttl }
```

### Key Relationships

- **BaseRegistrar** inherits Solady `ERC721` + `Ownable`. It owns the `baseNode` in the Registry.
- **Controllers** are whitelisted via `BaseRegistrar.addController(address)` (onlyOwner). Only controllers can call `register`, `registerWithRecord`, `renew`.
- **Resolvers** (`L2Resolver` or `UpgradeableL2Resolver`) store all profile records (addr, text, contenthash, etc.). Authorization: registry owner, approved operators, trusted controllers, or reverse registrar.
- **Reverse Registrar** manages `addr -> name` mappings under a Base-specific reverse node.

## Name Lifecycle

1. **Registration**: Controller calls `BaseRegistrar.registerWithRecord()` -> mints ERC721, sets `nameExpires[id]`, writes Registry subnode.
2. **Active period**: `ownerOf()` works, transfers allowed, records can be set.
3. **Expiry**: `nameExpires[id] <= block.timestamp` -> `ownerOf()` reverts, transfers blocked (via `onlyNonExpired` on `_isApprovedOrOwner`).
4. **Grace period**: 90 days post-expiry. Name not available for new registration. Existing owner can still `renew`.
5. **Available**: After grace period. Anyone can register.

## Transfer Mechanics

- Standard ERC721 transfers (Solady). No `_beforeTokenTransfer` hook or soul-bound lock exists.
- `_isApprovedOrOwner` and `ownerOf` are gated by `onlyNonExpired` -- expired names cannot be transferred.
- After transfer, new holder must call `reclaim(id, owner)` to sync Registry ownership with the NFT.

## Expiry Storage

- `mapping(uint256 id => uint256 expiry) public nameExpires` on BaseRegistrar.
- `renew(id, duration)` adds duration to existing expiry (controller-only).
- A sentinel value of `type(uint256).max` would effectively mean "never expires" since no `block.timestamp` will exceed it.

## Resolver & Text Records

- `TextResolver.setText(node, key, value)` / `text(node, key)` -- ENSIP-5 compliant, any UTF-8 key allowed.
- Records are versioned per node; `clearRecords(node)` increments version to invalidate old data.
- Common convention keys: `avatar`, `url`, `description`, `com.twitter`, `com.github`. No protocol-enforced key registry.
- Registration controllers can batch-set records via `multicallWithNodeCheck` during registration.

## Pricing

- `IPriceOracle.price(name, expires, duration) -> Price { base, premium }`.
- `StablePriceOracle`: per-second rent by name length tier.
- `LaunchAuctionPriceOracle`: Dutch auction premium for initial launch.
- `ExponentialPremiumPriceOracle`: premium decay for post-expiry re-registration.
- Renewals charge **base only**, no premium.

## Discount System

- `DiscountDetails { active, discountValidator, key, discount }` -- flat wei subtraction.
- Pluggable via `IDiscountValidator.isValidDiscountRegistration(claimer, data)`.
- One discounted registration per address (tracked across legacy + current controller).
- Existing validators: Attestation, CBId (Merkle), Coupon, Signature, ERC721, ERC1155, TalentProtocol.

## Controller Variants

| Controller | Upgradeable | Key Differences |
|------------|-------------|-----------------|
| `RegistrarController` | No | `launchTime` for auction premium anchor, legacy reverse |
| `UpgradeableRegistrarController` | Yes (UUPS) | ENSIP-19 `RegisterRequest`, legacy controller integration, L2ReverseRegistrar |
| `EARegistrarController` | No | Early access only, 28-day min duration, discount-only |

## Adding New Controllers

A new controller can be granted registration powers via `BaseRegistrar.addController(newController)`. This is the primary extension point -- new business logic (soul-bound, free, promotional) can be added without modifying existing contracts.
