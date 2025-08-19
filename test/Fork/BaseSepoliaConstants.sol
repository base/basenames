// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

library BaseSepolia {
    // ENS / Basenames addresses on Base Sepolia
    address constant REGISTRY = 0x1493b2567056c2181630115660963E13A8E32735;
    address constant BASE_REGISTRAR = 0xA0c70ec36c010B55E3C434D6c6EbEEC50c705794;
    address constant LEGACY_GA_CONTROLLER = 0x49aE3cC2e3AA768B1e5654f5D3C6002144A59581;
    address constant LEGACY_L2_RESOLVER = 0x6533C94869D28fAA8dF77cc63f9e2b2D6Cf77eBA;
    // ReverseRegistrar with correct reverse node configured for Base Sepolia
    address constant LEGACY_REVERSE_REGISTRAR = 0x876eF94ce0773052a2f81921E70FF25a5e76841f;
    // Old reverse registrar with incorrect reverse node configured for Base Sepolia
    // address constant LEGACY_REVERSE_REGISTRAR = 0xa0A8401ECF248a9375a0a71C4dedc263dA18dCd7;

    address constant UPGRADEABLE_CONTROLLER_PROXY = 0x82c858CDF64b3D893Fe54962680edFDDC37e94C8;
    address constant UPGRADEABLE_L2_RESOLVER_PROXY = 0x85C87e548091f204C2d0350b39ce1874f02197c6;

    // ENS L2 Reverse Registrar (ENS-managed) on Base Sepolia
    address constant ENS_L2_REVERSE_REGISTRAR = 0x00000BeEF055f7934784D6d81b6BC86665630dbA;

    // Ops / controllers
    address constant L2_OWNER = 0xdEC57186e5dB11CcFbb4C932b8f11bD86171CB9D;
    address constant MIGRATION_CONTROLLER = 0xE8A87034a06425476F2bD6fD14EA038332Cc5e10;

    // ENSIP-11 Base Sepolia cointype
    uint256 constant BASE_SEPOLIA_COINTYPE = 2147568180;

    // ENSIP-19 Base Sepolia reverse parent node: namehash("80014a34.reverse")
    bytes32 constant BASE_SEPOLIA_REVERSE_NODE = 0x9831acb91a733dba6ffe6c6e872dd546b8c24e2dbd225f3616a8c670cbbd8b8a;
}
