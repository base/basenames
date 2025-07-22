# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is the Basenames repository - a Solidity-based implementation enabling ENS subdomain registration on Base network as `*.base.eth` subdomains. It's a fork of ENS contracts optimized for Base L2, supporting name registration, resolution, and management with ERC721 tokenization.

## Key Architecture

### Core Components
- **Registry**: Stores subdomain records in flat structure (`src/L2/Registry.sol`)
- **BaseRegistrar**: Tokenizes names as ERC721, manages ownership/expiry (`src/L2/BaseRegistrar.sol`)
- **RegistrarController**: Handles registration payments and discounts (`src/L2/RegistrarController.sol`)
- **L1Resolver**: Enables cross-chain resolution from Ethereum mainnet (`src/L1/L1Resolver.sol`)
- **L2Resolver**: Standard public resolver for Base records (`src/L2/L2Resolver.sol`)
- **ReverseRegistrar**: Manages reverse lookups for primary names (`src/L2/ReverseRegistrar.sol`)

### Pricing Oracles
- **StablePriceOracle**: Base pricing by name length/duration
- **ExponentialPremiumPriceOracle**: Dutch auction for expired names
- **LaunchAuctionPriceOracle**: Special launch pricing mechanism

### Discount System
All discount validators implement `IDiscountValidator` interface:
- **CBIdDiscountValidator**: Coinbase ID integration
- **ERC1155DiscountValidator**: ERC1155 token holders
- **ERC721DiscountValidator**: ERC721 token holders
- **AttestationValidator**: EAS attestation-based discounts
- **CouponDiscountValidator**: Signature-based coupons
- **TalentProtocolDiscountValidator**: Talent Protocol integration

## Development Commands

### Core Foundry Commands
```bash
forge build           # Compile contracts
forge test            # Run all tests
forge test --mt <name> # Run specific test
forge fmt             # Format code
forge snapshot        # Generate gas snapshots
```

### Security Analysis
```bash
slither .             # Static analysis (config: slither.config.json)
```

### Test Categories
- Component tests: `test/{Component}/` - Unit tests for each contract
- Integration tests: `test/Integration/` - Cross-contract functionality
- Discount tests: `test/discounts/` - Validator implementations
- Fuzz tests: Files ending with `FuzzTest.t.sol`

### Scripts and Deployment
- Deploy scripts: `script/deploy/`
- Configuration scripts: `script/configure/`
- Premint operations: `script/premint/` (see Makefile for batch operations)

## Important File Locations

### Source Code Structure
- `src/L1/`: Ethereum mainnet contracts
- `src/L2/`: Base network contracts  
- `src/L2/discounts/`: Discount validator implementations
- `src/L2/interface/`: Contract interfaces
- `src/lib/`: Shared utilities and libraries
- `src/util/`: Constants and helper functions

### Testing Structure
Tests mirror source structure with comprehensive coverage for each component.

### Configuration
- `foundry.toml`: Foundry configuration with remappings
- `slither.config.json`: Security analysis configuration
- Contract addresses for mainnet/testnet available in README.md

## Development Notes

- Uses Foundry framework exclusively
- Comprehensive test suite with fuzz testing
- Security-focused with Slither integration
- Multi-network deployment (Ethereum mainnet, Base mainnet, testnets)
- Extensive use of OpenZeppelin contracts and ENS libraries
- Python utilities in `py/` for price calculations and BNS operations