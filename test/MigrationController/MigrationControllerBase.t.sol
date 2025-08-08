//SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {MigrationController} from "src/L2/MigrationController.sol";
import {MockAddrResolver} from "test/mocks/MockAddrResolver.sol";
import {NameEncoder} from "ens-contracts/utils/NameEncoder.sol";
import {Registry} from "src/L2/Registry.sol";
import {Test} from "forge-std/Test.sol";

import {ETH_NODE, BASE_ETH_NODE, REVERSE_NODE, BASE_REVERSE_NODE, BASE_ETH_NAME} from "src/util/Constants.sol";

contract MigrationControllerBase is Test {
    MigrationController migrationController;
    Registry registry;
    MockAddrResolver resolver;

    uint256 constant BASE_COINTYPE = 0x80002105;
    bytes32 constant ROOT_NODE = bytes32(0);
    bytes32 constant ETH_LABEL = 0x4f5b812789fc606be1b3b16908db13fc7a9adf7ca72641f84d75b47069d3d7f0;
    bytes32 constant BASE_LABEL = 0xf1f3eb40f5bc1ad1344716ced8b8a0431d840b5783aea1fd01786bc26f35ac0f;

    address owner = makeAddr("owner");
    address alice = makeAddr("alice");

    string aliceName = "alice";
    string fullAliceName = "alice.base.eth";
    bytes32 aliceNode;
    bytes32 aliceLabel;

    function setUp() public {
        aliceLabel = keccak256(bytes(aliceName));
        (, aliceNode) = NameEncoder.dnsEncodeName(fullAliceName);

        registry = new Registry(owner);

        resolver = new MockAddrResolver();
        _establishNamespace();

        migrationController = new MigrationController(registry, BASE_COINTYPE, address(resolver), owner);
    }

    function _establishNamespace() internal {
        // establish base.eth namespace and assign ownership of base.eth to the owner
        vm.startPrank(owner);
        registry.setSubnodeOwner(ROOT_NODE, ETH_LABEL, owner);
        registry.setSubnodeOwner(ETH_NODE, BASE_LABEL, owner);
        vm.stopPrank();
    }

    // alice.base.eth to alice with resolver.
    function _setupAliceNode() internal {
        vm.prank(owner);
        registry.setSubnodeRecord(BASE_ETH_NODE, aliceLabel, alice, address(resolver), 0);
    }

    function _createAddrResolverRecord() internal {
        vm.prank(alice);
        resolver.setAddr(aliceNode, alice);
    }

    function _createBaseAddrResolverRecord() internal {
        vm.prank(alice);
        resolver.setAddr(aliceNode, BASE_COINTYPE, addressToBytes(alice));
    }

    function _getNodesArray() internal view returns (bytes32[] memory) {
        bytes32[] memory nodes = new bytes32[](1);
        nodes[0] = aliceNode;
        return nodes;
    }

    function bytesToAddress(bytes memory b) internal pure returns (address payable a) {
        require(b.length == 20);
        assembly {
            a := div(mload(add(b, 32)), exp(256, 12))
        }
    }

    function addressToBytes(address a) internal pure returns (bytes memory b) {
        b = new bytes(20);
        assembly {
            mstore(add(b, 32), mul(a, exp(256, 12)))
        }
    }
}
