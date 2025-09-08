![basenames-cover](https://github.com/user-attachments/assets/14f63206-5838-4938-9a84-f9165e431f96)
# BASENAMES


This repository contains code for minting and managing [ENS](https://docs.ens.domains/) subdomains on the Base network as `base.eth` subdomains. 

It supports:
- Registering base.eth subdomains on Base natively
- Managing the name with a public resolver, allowing an owner or operator to set address records, text records, dns records, etc.
- ERC721 subdomain tokens [(Opensea)](https://opensea.io/collection/basenames)

### OVERVIEW

Basenames are a core onchain building block that enables anyone to establish their identity on Base by registering human-readable names for their address(es). They are a fully onchain solution which leverages ENS infrastructure deployed on Base.

### CONTRACT ADDRESSES

#### Ethereum Mainnet

| Contract | Address | 
| -------- | ------- |
| L1Resolver | [0xde9049636F4a1dfE0a64d1bFe3155C0A14C54F31](https://etherscan.io/address/0xde9049636F4a1dfE0a64d1bFe3155C0A14C54F31) |

#### Base Mainnet

| Contract | Address | 
| -------- | ------- | 
| Registry | [0xb94704422c2a1e396835a571837aa5ae53285a95](https://basescan.org/address/0xb94704422c2a1e396835a571837aa5ae53285a95) | 
| BaseRegistrar | [0x03c4738ee98ae44591e1a4a4f3cab6641d95dd9a](https://basescan.org/address/0x03c4738ee98ae44591e1a4a4f3cab6641d95dd9a) | 
| RegistrarController | [0x4cCb0BB02FCABA27e82a56646E81d8c5bC4119a5](https://basescan.org/address/0x4cCb0BB02FCABA27e82a56646E81d8c5bC4119a5) |
| Launch Price Oracle | [0xd53b558e1f07289acedf028d226974abba258312](https://basescan.org/address/0xd53b558e1f07289acedf028d226974abba258312) |
| Price Oracle | [0x508CFE43aa84b8048cB6d39037cE0dc96d8aDc75](https://basescan.org/address/0x508CFE43aa84b8048cB6d39037cE0dc96d8aDc75) | 
| ReverseRegistrar | [0x79ea96012eea67a83431f1701b3dff7e37f9e282](https://basescan.org/address/0x79ea96012eea67a83431f1701b3dff7e37f9e282) | 
| L2Resolver | [0xC6d566A56A1aFf6508b41f6c90ff131615583BCD](https://basescan.org/address/0xC6d566A56A1aFf6508b41f6c90ff131615583BCD) | 
| MigrationController | [0x8d5ef54f900c82da119B4a7F960A92F3Fa8daB43](https://basescan.org/address/0x8d5ef54f900c82da119B4a7F960A92F3Fa8daB43) |
| UpgradeableRegistrarController (Implementation) | [0x9ad14968093C5E8C2A8CC86f6868CFEE8C659717](https://basescan.org/address/0x9ad14968093C5E8C2A8CC86f6868CFEE8C659717) |
| UpgradeableRegistrarController (Proxy) | [0xa7d2607c6BD39Ae9521e514026CBB078405Ab322](https://basescan.org/address/0xa7d2607c6BD39Ae9521e514026CBB078405Ab322) |
| UpgradeableL2Resolver (Implementation) | [0xf74b949f2105178eEEd4Ef35a131715E967337ab](https://basescan.org/address/0xf74b949f2105178eEEd4Ef35a131715E967337ab) |
| UpgradeableL2Resolver (Proxy) | [0x426fA03fB86E510d0Dd9F70335Cf102a98b10875](https://basescan.org/address/0x426fA03fB86E510d0Dd9F70335Cf102a98b10875) |
| ProxyAdmin | [0x6c8E23DaCCc002d2Bca7608EC0351E434E74d5a8](https://basescan.org/address/0x6c8E23DaCCc002d2Bca7608EC0351E434E74d5a8) |

#### Sepolia

| Contract | Address | 
| -------- | ------- |
| L1Resolver | [0x084D10C07EfEecD9fFc73DEb38ecb72f9eEb65aB](https://sepolia.etherscan.io/address/0x084D10C07EfEecD9fFc73DEb38ecb72f9eEb65aB) |

#### Base Sepolia

| Contract | Address | 
| -------- | ------- | 
| Registry | [0x1493b2567056c2181630115660963E13A8E32735](https://sepolia.basescan.org/address/0x1493b2567056c2181630115660963E13A8E32735) | 
| BaseRegistrar | [0xa0c70ec36c010b55e3c434d6c6ebeec50c705794](https://sepolia.basescan.org/address/0xa0c70ec36c010b55e3c434d6c6ebeec50c705794) | 
| RegistrarController | [0x49ae3cc2e3aa768b1e5654f5d3c6002144a59581](https://sepolia.basescan.org/address/0x49ae3cc2e3aa768b1e5654f5d3c6002144a59581) |
| Launch Price Oracle | [0x2afF926546f5fbe3E10315CC9C0827AF1A167aC8](https://sepolia.basescan.org/address/0x2afF926546f5fbe3E10315CC9C0827AF1A167aC8) |
| Price Oracle | [0x2b73408052825e17e0fe464f92de85e8c7723231](https://sepolia.basescan.org/address/0x2b73408052825e17e0fe464f92de85e8c7723231) | 
| ReverseRegistrar | [0x876eF94ce0773052a2f81921E70FF25a5e76841f](https://sepolia.basescan.org/address/0x876eF94ce0773052a2f81921E70FF25a5e76841f) | 
| L2Resolver | [0x6533C94869D28fAA8dF77cc63f9e2b2D6Cf77eBA](https://sepolia.basescan.org/address/0x6533C94869D28fAA8dF77cc63f9e2b2D6Cf77eBA) | 
| MigrationController | [0xE8A87034a06425476F2bD6fD14EA038332Cc5e10](https://sepolia.basescan.org/address/0xE8A87034a06425476F2bD6fD14EA038332Cc5e10) |
| UpgradeableRegistrarController (Implementation) | [0xb53e99F4a96dce67E772038a32aBd1131E216770](https://sepolia.basescan.org/address/0xb53e99F4a96dce67E772038a32aBd1131E216770) |
| UpgradeableRegistrarController (Proxy) | [0x82c858CDF64b3D893Fe54962680edFDDC37e94C8](https://sepolia.basescan.org/address/0x82c858CDF64b3D893Fe54962680edFDDC37e94C8) |
| UpgradeableL2Resolver (Implementation) | [0xC014B9c02b0EDeA17255Ce019e6ab6c24E4AD073](https://sepolia.basescan.org/address/0xC014B9c02b0EDeA17255Ce019e6ab6c24E4AD073) |
| UpgradeableL2Resolver (Proxy) | [0x85C87e548091f204C2d0350b39ce1874f02197c6](https://sepolia.basescan.org/address/0x85C87e548091f204C2d0350b39ce1874f02197c6) |
| ProxyAdmin | [0xE6F8309b75E73ace9d2b73531880126D883ae904](https://sepolia.basescan.org/address/0xE6F8309b75E73ace9d2b73531880126D883ae904) |

## Functional Diagram

The system architecture can be functionally organized into three categories:
1. An L1 resolver enabling cross-chain resolution for the `base.eth` 2LD.
2. An ENS-like registry/registrar/resolver system deployed on Base enabling `*.base.eth` subdomains to be registered and managed.
3. An off-chain gateway for serving CCIP requests required to comply with [ENSIP-10](https://docs.ens.domains/ensip/10). 

![Screenshot 2024-06-16 at 8 51 55 PM](https://github.com/base-org/usernames/assets/84420280/3689dd40-2be0-4a7d-8454-155741a1add0)

### ARCHITECTURE

The core functionality of Base Usernames should look familiar to anyone that's looked under the hood  at the [ENS contracts](https://github.com/ensdomains/ens-contracts/tree/staging). We implement a slimmed down fork of the ENS contracts here.

| Contract | Role | ENS Implementation | Base Usernames Implementation |
| -------- | ----- | ------------------ | ----------------------------- | 
|[Registry](https://docs.ens.domains/registry/ens)  | Stores [Records](https://github.com/base/basenames/blob/c29119fd327b61f896440c317f3dd898e9fa570b/contracts/src/L2/Registry.sol#L7-L11) of subdomains in a flat structure |  [ENSRegistry.sol](https://github.com/ensdomains/ens-contracts/blob/staging/contracts/registry/ENSRegistry.sol) | [Registry.sol](https://github.com/base/basenames/blob/main/src/L2/Registry.sol) |
| [BaseRegistrar](https://docs.ens.domains/registry/eth) | Tokenizes names,  manages ownership and stores expiry | [BaseRegistrarImplementation.sol](https://github.com/ensdomains/ens-contracts/blob/staging/contracts/ethregistrar/BaseRegistrarImplementation.sol) | [BaseRegistrar.sol](https://github.com/base/basenames/blob/main/src/L2/BaseRegistrar.sol) | 
| [ReverseRegistrar](https://docs.ens.domains/registry/reverse) | Manages the reverse lookup to allow the setting of "primary" names for an address | [ReverseRegistrar.sol](https://github.com/ensdomains/ens-contracts/blob/staging/contracts/reverseRegistrar/ReverseRegistrar.sol) | [ReverseRegistrar.sol](https://github.com/base/basenames/blob/main/src/L2/ReverseRegistrar.sol) |
| [L1 Resolver](https://docs.ens.domains/resolvers/ccip-read) | Enables cross-chain, wildcard resolution from L1 | [OffchainResolver.sol](https://github.com/ensdomains/offchain-resolver/blob/main/packages/contracts/contracts/OffchainResolver.sol) | [L1Resolver.sol](https://github.com/base/basenames/blob/main/src/L1/L1Resolver.sol) | 
| [L2 Resolver](https://docs.ens.domains/resolvers/public) | A standard public resolver for storing records associated with namespaces | [PublicResolver.sol](https://github.com/ensdomains/ens-contracts/blob/staging/contracts/resolvers/PublicResolver.sol) | [L2Resolver.sol](https://github.com/base/basenames/blob/main/src/L2/L2Resolver.sol) | 
| Registrar Controller | A permissioned contract which manages registration payment | [ETHRegistrarController.sol](https://github.com/ensdomains/ens-contracts/blob/staging/contracts/ethregistrar/ETHRegistrarController.sol) | [RegistrarController.sol](https://github.com/base/basenames/blob/main/src/L2/RegistrarController.sol) |
| Stable Price Oracle | The source of pricing based on name length and duration of registration | [StablePriceOracle.sol](https://github.com/ensdomains/ens-contracts/blob/staging/contracts/ethregistrar/StablePriceOracle.sol) | [StablePriceOracle.sol](https://github.com/base/basenames/blob/main/src/L2/StablePriceOracle.sol) |
| Exponential Premium Oracle | A Dutch auction pricing mechanism for fairly pricing names after expiry | [ExponentialPremiumPricingOracle.sol](https://github.com/ensdomains/ens-contracts/blob/staging/contracts/ethregistrar/ExponentialPremiumPriceOracle.sol) | [ExponentialPremiumPricingOracle.sol](https://github.com/base/basenames/blob/main/src/L2/ExponentialPremiumPriceOracle.sol) |

In addition to replicating the base behavior of the ENS protocol, we are offering a series of promotional discounts associated with various Coinbase product integrations. As such, the Base Usernames Registrar Controller allows users to perform discounted registrations while passing along integration-specific `validationData`. Each discount leverages a common interface: 
```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

/// @title Discount Validator Interface
///
/// @notice Common interface which all Discount Validators must implement.
///         The logic specific to each integration must ultimately be consumable as the `bool` returned from
///         `isValidDiscountRegistration`.
interface IDiscountValidator {
    /// @notice Required implementation for compatibility with IDiscountValidator.
    ///
    /// @dev Each implementation will have unique requirements for the data necessary to perform
    ///     a meaningful validation. Implementations must describe here how to pack relevant `validationData`.
    ///     Ex: `bytes validationData = abi.encode(bytes32 key, bytes32[] proof)`
    ///
    /// @param claimer the discount claimer's address.
    /// @param validationData opaque bytes for performing the validation.
    ///
    /// @return `true` if the validation data provided is determined to be valid for the specified claimer, else `false`.
    function isValidDiscountRegistration(address claimer, bytes calldata validationData) external returns (bool);
}
```
The various implementations can be found [in this directory](https://github.com/base/basenames/tree/main/src/L2/discounts). 

## Usage

### Build

```shell
$ forge build
```

### Test

```shell
$ forge test
```

### Format

```shell
$ forge fmt
```

### Gas Snapshots

```shell
$ forge snapshot
```

### Help

```shell
$ forge --help
$ anvil --help
$ cast --help
```
