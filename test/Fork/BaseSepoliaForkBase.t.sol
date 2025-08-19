// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Test} from "forge-std/Test.sol";
import {RegistrarController} from "src/L2/RegistrarController.sol";
import {UpgradeableRegistrarController} from "src/L2/UpgradeableRegistrarController.sol";
import {ENS} from "ens-contracts/registry/ENS.sol";
import {NameResolver} from "ens-contracts/resolvers/profiles/NameResolver.sol";
import {IL2ReverseRegistrar} from "src/L2/interface/IL2ReverseRegistrar.sol";

import {BASE_ETH_NODE} from "src/util/Constants.sol";

contract BaseSepoliaForkBase is Test {
    // RPC alias must be configured in foundry.toml as `base-sepolia`.
    string internal constant FORK_ALIAS = "base-sepolia";

    // Addresses from Terraform output
    address internal constant ENS_REGISTRY = 0x1493b2567056c2181630115660963E13A8E32735;
    address internal constant BASE_REGISTRAR = 0xA0c70ec36c010B55E3C434D6c6EbEEC50c705794;
    address internal constant LEGACY_GA_CONTROLLER = 0x49aE3cC2e3AA768B1e5654f5D3C6002144A59581;
    address internal constant LEGACY_L2_RESOLVER = 0x6533C94869D28fAA8dF77cc63f9e2b2D6Cf77eBA;
    address internal constant LEGACY_REVERSE_REGISTRAR = 0xa0A8401ECF248a9375a0a71C4dedc263dA18dCd7;

    address internal constant UPGRADEABLE_CONTROLLER_PROXY = 0x82c858CDF64b3D893Fe54962680edFDDC37e94C8;
    address internal constant UPGRADEABLE_L2_RESOLVER_PROXY = 0x85C87e548091f204C2d0350b39ce1874f02197c6;

    // ENS L2 Reverse Registrar (Base Sepolia) per ENS docs
    address internal constant ENS_L2_REVERSE_REGISTRAR = 0x00000BeEF055f7934784D6d81b6BC86665630dbA;

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
        return keccak256(abi.encodePacked(baseReverseParentNode, _sha3HexAddress(addr)));
    }

    function _sha3HexAddress(address addr) internal pure returns (bytes32 ret) {
        bytes16 lookup = 0x30313233343536373839616263646566;
        assembly {
            let i := 40
            let n := addr
            let ptr := mload(0x40)
            mstore(0x40, add(ptr, 64))
            for {} gt(i, 0) {} {
                i := sub(i, 1)
                mstore8(add(ptr, i), byte(and(n, 0x0f), lookup))
                n := shr(4, n)
                i := sub(i, 1)
                mstore8(add(ptr, i), byte(and(n, 0x0f), lookup))
                n := shr(4, n)
                if iszero(i) { break }
            }
            ret := keccak256(ptr, 40)
        }
    }

    // Build a signature for ENS L2 Reverse Registrar setNameForAddrWithSignature, EIP-191 style
    function _buildL2ReverseSignature(string memory fullName, uint256[] memory coinTypes, uint256 expiry)
        internal
        view
        returns (bytes memory)
    {
        // bytes32 message = keccak256(abi.encodePacked(address(this), selector, addr, expiry, name, coinTypes)).toEthSignedMessageHash();
        bytes4 selector = IL2ReverseRegistrar.setNameForAddrWithSignature.selector;
        bytes32 inner =
            keccak256(abi.encodePacked(ENS_L2_REVERSE_REGISTRAR, selector, user, expiry, fullName, coinTypes));
        bytes32 digest = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", inner));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(userPk, digest);
        return abi.encodePacked(r, s, v);
    }
}
