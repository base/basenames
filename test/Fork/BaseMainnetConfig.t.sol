// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {AbstractForkSuite} from "./AbstractForkSuite.t.sol";
import {BaseMainnet as C} from "./BaseMainnetConstants.sol";

abstract contract BaseMainnetConfig is AbstractForkSuite {
    function forkAlias() internal pure override returns (string memory, uint256) {
        return ("base-mainnet", 35_370_443); // Last ENSIP-19 setup config was run here: https://basescan.org/block/35370442. Increment one block.
    }

    function registry() internal pure override returns (address) {
        return C.REGISTRY;
    }

    function baseRegistrar() internal pure override returns (address) {
        return C.BASE_REGISTRAR;
    }

    function legacyGaController() internal pure override returns (address) {
        return C.LEGACY_GA_CONTROLLER;
    }

    function legacyL2Resolver() internal pure override returns (address) {
        return C.LEGACY_L2_RESOLVER;
    }

    function legacyReverseRegistrar() internal pure override returns (address) {
        return C.LEGACY_REVERSE_REGISTRAR;
    }

    function upgradeableControllerProxy() internal pure override returns (address) {
        return C.UPGRADEABLE_CONTROLLER_PROXY;
    }

    function upgradeableL2ResolverProxy() internal pure override returns (address) {
        return C.UPGRADEABLE_L2_RESOLVER_PROXY;
    }

    function ensL2ReverseRegistrar() internal pure override returns (address) {
        return C.ENS_L2_REVERSE_REGISTRAR;
    }

    function l2Owner() internal pure override returns (address) {
        return C.L2_OWNER;
    }

    function migrationController() internal pure override returns (address) {
        return C.MIGRATION_CONTROLLER;
    }

    function baseCoinType() internal pure override returns (uint256) {
        return C.BASE_MAINNET_COINTYPE;
    }

    function baseReverseParentNode() internal pure override returns (bytes32) {
        return C.BASE_MAINNET_REVERSE_NODE;
    }
}
