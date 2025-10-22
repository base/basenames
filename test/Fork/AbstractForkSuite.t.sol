// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Test} from "forge-std/Test.sol";
import {ENS} from "ens-contracts/registry/ENS.sol";
import {NameResolver} from "ens-contracts/resolvers/profiles/NameResolver.sol";

import {RegistrarController} from "src/L2/RegistrarController.sol";
import {UpgradeableRegistrarController} from "src/L2/UpgradeableRegistrarController.sol";
import {IL2ReverseRegistrar} from "src/L2/interface/IL2ReverseRegistrar.sol";
import {IReverseRegistrar} from "src/L2/interface/IReverseRegistrar.sol";
import {Sha3} from "src/lib/Sha3.sol";
import {BASE_ETH_NODE} from "src/util/Constants.sol";

abstract contract AbstractForkSuite is Test {
    // Network configuration hooks
    function forkAlias() internal pure virtual returns (string memory, uint256);

    function registry() internal pure virtual returns (address);
    function baseRegistrar() internal pure virtual returns (address);
    function legacyGaController() internal pure virtual returns (address);
    function legacyL2Resolver() internal pure virtual returns (address);
    function legacyReverseRegistrar() internal pure virtual returns (address);

    function upgradeableControllerProxy() internal pure virtual returns (address);
    function upgradeableL2ResolverProxy() internal pure virtual returns (address);

    function ensL2ReverseRegistrar() internal pure virtual returns (address);
    function l2Owner() internal pure virtual returns (address);
    function migrationController() internal pure virtual returns (address);

    function baseCoinType() internal pure virtual returns (uint256);
    function baseReverseParentNode() internal pure virtual returns (bytes32);

    // Actors
    uint256 internal userPk;
    address internal user;

    // Interfaces
    RegistrarController internal legacyController;
    UpgradeableRegistrarController internal upgradeableController;
    NameResolver internal legacyResolver;
    IL2ReverseRegistrar internal l2ReverseRegistrar;

    // Aliased constants for readability in scenarios
    address internal REGISTRY;
    address internal BASE_REGISTRAR;
    address internal LEGACY_GA_CONTROLLER;
    address internal LEGACY_L2_RESOLVER;
    address internal LEGACY_REVERSE_REGISTRAR;
    address internal UPGRADEABLE_CONTROLLER_PROXY;
    address internal UPGRADEABLE_L2_RESOLVER_PROXY;
    address internal ENS_L2_REVERSE_REGISTRAR;
    address internal L2_OWNER;
    address internal MIGRATION_CONTROLLER;

    function setUp() public virtual {
        (string memory forkUrl, uint256 blockNumber) = forkAlias();
        vm.createSelectFork(forkUrl, blockNumber);

        // Bind constants
        REGISTRY = registry();
        BASE_REGISTRAR = baseRegistrar();
        LEGACY_GA_CONTROLLER = legacyGaController();
        LEGACY_L2_RESOLVER = legacyL2Resolver();
        LEGACY_REVERSE_REGISTRAR = legacyReverseRegistrar();
        UPGRADEABLE_CONTROLLER_PROXY = upgradeableControllerProxy();
        UPGRADEABLE_L2_RESOLVER_PROXY = upgradeableL2ResolverProxy();
        ENS_L2_REVERSE_REGISTRAR = ensL2ReverseRegistrar();
        L2_OWNER = l2Owner();
        MIGRATION_CONTROLLER = migrationController();

        // Create a deterministic EOA we control for signing
        userPk = uint256(keccak256("basenames.fork.user"));
        user = vm.addr(userPk);

        legacyController = RegistrarController(LEGACY_GA_CONTROLLER);
        upgradeableController = UpgradeableRegistrarController(UPGRADEABLE_CONTROLLER_PROXY);
        legacyResolver = NameResolver(LEGACY_L2_RESOLVER);
        l2ReverseRegistrar = IL2ReverseRegistrar(ENS_L2_REVERSE_REGISTRAR);
    }

    function _labelFor(string memory name) internal pure returns (bytes32) {
        return keccak256(bytes(name));
    }

    function _nodeFor(string memory name) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(BASE_ETH_NODE, _labelFor(name)));
    }

    function _fullName(string memory name) internal view returns (string memory) {
        // Use controller-provided root name to avoid hardcoding suffixes
        return string.concat(name, legacyController.rootName());
    }

    function _baseReverseNode(address addr, bytes32 baseReverseParent) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(baseReverseParent, Sha3.hexAddress(addr)));
    }

    // Build a signature for ENS L2 Reverse Registrar setNameForAddrWithSignature, EIP-191 style
    function _buildL2ReverseSignature(string memory fullName, uint256[] memory coinTypes, uint256 expiry)
        internal
        view
        returns (bytes memory)
    {
        bytes4 selector = IL2ReverseRegistrar.setNameForAddrWithSignature.selector;
        bytes32 inner =
            keccak256(abi.encodePacked(ENS_L2_REVERSE_REGISTRAR, selector, user, expiry, fullName, coinTypes));
        bytes32 digest = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", inner));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(userPk, digest);
        return abi.encodePacked(r, s, v);
    }

    function _addressToBytes(address a) internal pure returns (bytes memory b) {
        b = new bytes(20);
        assembly {
            mstore(add(b, 32), mul(a, exp(256, 12)))
        }
    }
}
