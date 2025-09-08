// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

library BaseMainnet {
    // ENS / Basenames addresses on Base Mainnet
    address constant REGISTRY = 0xB94704422c2a1E396835A571837Aa5AE53285a95;
    address constant BASE_REGISTRAR = 0x03c4738Ee98aE44591e1A4A4F3CaB6641d95DD9a;
    address constant LEGACY_GA_CONTROLLER = 0x4cCb0BB02FCABA27e82a56646E81d8c5bC4119a5;
    address constant LEGACY_L2_RESOLVER = 0xC6d566A56A1aFf6508b41f6c90ff131615583BCD;
    // ReverseRegistrar with correct reverse node configured for Base Mainnet
    address constant LEGACY_REVERSE_REGISTRAR = 0x79EA96012eEa67A83431F1701B3dFf7e37F9E282;

    address constant UPGRADEABLE_CONTROLLER_PROXY = 0xa7d2607c6BD39Ae9521e514026CBB078405Ab322;
    address constant UPGRADEABLE_L2_RESOLVER_PROXY = 0x426fA03fB86E510d0Dd9F70335Cf102a98b10875;

    // ENS L2 Reverse Registrar (ENS-managed) on Base Mainnet
    address constant ENS_L2_REVERSE_REGISTRAR = 0x0000000000D8e504002cC26E3Ec46D81971C1664;

    // Ops / controllers
    address constant L2_OWNER = 0xf9BbA2F07a2c95fC4225f1CAeC76E6BF04B463e9;
    address constant MIGRATION_CONTROLLER = 0x8d5ef54f900c82da119B4a7F960A92F3Fa8daB43;

    // ENSIP-11 Base Mainnet cointype
    uint256 constant BASE_MAINNET_COINTYPE = 2147492101; // 0x80002105

    // ENSIP-19 Base Mainnet reverse parent node: namehash("80002105.reverse")
    bytes32 constant BASE_MAINNET_REVERSE_NODE = 0x08d9b0993eb8c4da57c37a4b84a6e384c2623114ff4e9370ed51c9b8935109ba;
}
