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

import {BaseSepolia as BaseSepoliaConstants} from "test/Fork/BaseSepoliaConstants.sol";
import {L2Resolver} from "src/L2/L2Resolver.sol";
import {ReverseRegistrar} from "src/L2/ReverseRegistrar.sol";

contract BaseSepoliaForkBase is Test {
    // RPC alias must be configured in foundry.toml as `base-sepolia`.
    string internal constant FORK_ALIAS = "base-sepolia";

    // Addresses from constants
    address internal constant REGISTRY = BaseSepoliaConstants.REGISTRY;
    address internal constant BASE_REGISTRAR = BaseSepoliaConstants.BASE_REGISTRAR;
    address internal constant LEGACY_GA_CONTROLLER = BaseSepoliaConstants.LEGACY_GA_CONTROLLER;
    address internal constant LEGACY_L2_RESOLVER = BaseSepoliaConstants.LEGACY_L2_RESOLVER;
    address internal constant LEGACY_REVERSE_REGISTRAR = BaseSepoliaConstants.LEGACY_REVERSE_REGISTRAR;

    address internal constant UPGRADEABLE_CONTROLLER_PROXY = BaseSepoliaConstants.UPGRADEABLE_CONTROLLER_PROXY;
    address internal constant UPGRADEABLE_L2_RESOLVER_PROXY = BaseSepoliaConstants.UPGRADEABLE_L2_RESOLVER_PROXY;

    // ENS L2 Reverse Registrar (Base Sepolia)
    address internal constant ENS_L2_REVERSE_REGISTRAR = BaseSepoliaConstants.ENS_L2_REVERSE_REGISTRAR;

    // Owners / ops
    address internal constant L2_OWNER = BaseSepoliaConstants.L2_OWNER;

    // Actors
    uint256 internal userPk;
    address internal user;

    // Interfaces
    RegistrarController internal legacyController;
    UpgradeableRegistrarController internal upgradeableController;
    NameResolver internal legacyResolver;
    IL2ReverseRegistrar internal l2ReverseRegistrar;

    function setUp() public virtual {
        vm.createSelectFork(FORK_ALIAS);

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

    function _fullName(string memory name) internal pure returns (string memory) {
        return string.concat(name, ".base.eth");
    }

    function _baseReverseNode(address addr, bytes32 baseReverseParentNode) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(baseReverseParentNode, Sha3.hexAddress(addr)));
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
}
