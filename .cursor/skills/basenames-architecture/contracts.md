# Basenames Contract Reference

Detailed reference for all contracts under `src/`.

## src/L2/BaseRegistrar.sol

The core tokenization layer. Inherits Solady `ERC721` + `Ownable`.

**Key state:**
- `mapping(uint256 id => uint256 expiry) public nameExpires`
- `mapping(address => bool) public controllers`
- `ENS public immutable registry`
- `bytes32 public immutable baseNode`

**Controller-only methods:**
- `register(id, owner, duration)` -- mint + registry subnode owner
- `registerOnly(id, owner, duration)` -- mint only, no registry update
- `registerWithRecord(id, owner, duration, resolver, ttl)` -- mint + full registry subnode record
- `renew(id, duration)` -- extend expiry (must be active or in grace)

**Owner-only methods:**
- `addController(address)` / `removeController(address)`
- `setResolver(address)` -- set resolver for the base node itself
- `setBaseTokenURI(string)` / `setContractURI(string)`

**Public methods:**
- `reclaim(id, owner)` -- sync registry ownership with NFT (caller must be approved/owner)
- `ownerOf(tokenId)` -- reverts if expired
- `isAvailable(id)` -- true if `nameExpires[id] + GRACE_PERIOD < block.timestamp`
- `nameExpires(id)` -- raw expiry timestamp

**Token ID:** `uint256(keccak256(bytes(label)))` where label is the subdomain string (e.g., "vitalik" for vitalik.base.eth).

**Transfer behavior:** Standard ERC721. `_isApprovedOrOwner` gated by `onlyNonExpired`. No soul-bound restrictions.

---

## src/L2/UpgradeableRegistrarController.sol

UUPS-upgradeable controller. Primary active controller for registrations.

**Storage (EIP-7201):**
- `IBaseRegistrar base`
- `IPriceOracle prices`
- `IReverseRegistrar reverseRegistrar`
- `address l2ReverseRegistrar`
- `bytes32 rootNode`, `string rootName`
- `address paymentReceiver`
- `address legacyRegistrarController`, `address legacyL2Resolver`
- `mapping(bytes32 => DiscountDetails) discounts`
- `mapping(address => bool) discountedRegistrants`
- `EnumerableSetLib.Bytes32Set activeDiscounts`

**Registration flow:**
1. `register(RegisterRequest)` -- validate name/duration, charge `registerPrice`, call `_register`
2. `discountedRegister(request, discountKey, validationData)` -- same but with discount applied
3. `_register` -> `base.registerWithRecord(...)` -> optionally `_setRecords` -> optionally `_setReverseRecord`
4. `renew(name, duration)` -- charges `price.base` only (no premium)

**RegisterRequest struct:** `{ name, owner, duration, resolver, data[], reverseRecord, coinTypes[], signatureExpiry, signature }`

**Constants:** `MIN_REGISTRATION_DURATION = 365 days`, `MIN_NAME_LENGTH = 3`

---

## src/L2/RegistrarController.sol

Legacy (non-upgradeable) controller. Similar to URC but with `launchTime` for auction premium and simpler reverse record flow.

---

## src/L2/EARegistrarController.sol

Early access controller. Only `discountedRegister` (no public `register`/`renew`). `MIN_REGISTRATION_DURATION = 28 days`.

---

## src/L2/Registry.sol

ENS-compatible registry. Stores `node -> Record { owner, resolver, ttl }`. Supports operators.

---

## src/L2/L2Resolver.sol

Public resolver for Base L2. Composes ENS profile resolvers (Addr, Text, ContentHash, ABI, etc.) + Multicallable + ExtendedResolver.

**Authorization (`isAuthorised`):**
- `msg.sender == registrarController` or `msg.sender == reverseRegistrar` -> always authorized
- Otherwise: must be registry owner of the node, or approved operator/delegate

---

## src/L2/UpgradeableL2Resolver.sol

Upgradeable variant of L2Resolver. Uses local `src/L2/resolver/` profile modules with EIP-7201 storage.

**Authorization (`isAuthorized`):**
- `approvedControllers[msg.sender]` or `msg.sender == reverseRegistrar` -> always authorized
- Otherwise: registry owner, operator, or delegate
- Supports multiple approved controllers (vs single in L2Resolver)

---

## src/L2/resolver/ (Profile Modules)

All extend `ResolverBase` (ERC165 + IVersionableResolver):
- `TextResolver` -- `setText(node, key, value)` / `text(node, key)` (ENSIP-5)
- `AddrResolver` -- ETH and multi-coin addresses (ENSIP-9/11)
- `NameResolver` -- reverse name string
- `ContentHashResolver`, `ABIResolver`, `DNSResolver`, `InterfaceResolver`, `PubkeyResolver`

---

## src/L2/ReverseRegistrar.sol

Manages `address -> name` reverse records under `BASE_REVERSE_NODE`. Controllers can `setNameForAddr`. Node for address: `keccak256(abi.encodePacked(reverseNode, hexAddress(addr)))`.

## src/L2/ReverseRegistrarV2.sol

Adds ENSIP-19 compliance via `IL2ReverseRegistrar.setNameForAddrWithSignature`.

---

## src/L2/StablePriceOracle.sol

Per-second rent by name length. 6 configurable tiers. Returns `Price { base, premium: 0 }`.

## src/L2/LaunchAuctionPriceOracle.sol

Extends StablePriceOracle. Adds Dutch auction premium with 1.5h half-life.

## src/L2/ExponentialPremiumPriceOracle.sol

Extends StablePriceOracle. Adds post-expiry premium decay (ENS-style).

---

## src/L2/discounts/

All implement `IDiscountValidator`:
- `AttestationValidator` -- EAS attestation + sybil resistance
- `CBIdDiscountValidator` -- Merkle proof for cb.id allowlist
- `CouponDiscountValidator` -- UUID coupon codes
- `SignatureDiscountValidator` -- Backend signer authorization
- `ERC721DiscountValidator` / `ERC1155DiscountValidator` / `ERC1155DiscountValidatorV2` -- NFT holdings
- `TalentProtocolDiscountValidator` -- Talent Protocol score

---

## src/L1/L1Resolver.sol

Ethereum mainnet resolver for `base.eth`. Implements CCIP-read (ERC-3668 / ENSIP-10) for wildcard resolution. Delegates root queries to `rootResolver`, subname queries to gateway + signers.

---

## src/lib/

- `EDAPrice.sol` -- Exponential decay pricing math
- `Sha3.sol` -- Keccak/name hashing helpers
- `SignatureVerifier.sol` -- ECDSA verification
- `SybilResistanceVerifier.sol` -- Discount attestation signatures

---

## src/util/Constants.sol

```solidity
bytes32 constant BASE_ETH_NODE = 0xff1e3c0eb00ec714e34b6114125fbde1dea2f24a72fbf672e7b7fd5690328e10;
bytes32 constant BASE_REVERSE_NODE = 0x08d9b0993eb8c4da57c37a4b84a6e384c2623114ff4e9370ed51c9b8935109ba;
uint256 constant GRACE_PERIOD = 90 days;
bytes constant BASE_ETH_NAME = hex"04626173650365746800"; // DNS-encoded "base.eth"
```
