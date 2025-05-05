//SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Test} from "forge-std/Test.sol";
import {ReverseRegistrarV2} from "src/L2/ReverseRegistrarV2.sol";
import {Registry} from "src/L2/Registry.sol";
import {ENS} from "ens-contracts/registry/ENS.sol";
import {MockL2ReverseRegistrar} from "test/mocks/MockL2ReverseRegistrar.sol";
import {MockNameResolver} from "test/mocks/MockNameResolver.sol";
import {ETH_NODE, REVERSE_NODE, BASE_REVERSE_NODE} from "src/util/Constants.sol";

contract ReverseRegistrarV2Base is Test {
    address public owner = makeAddr("owner");
    address public user = makeAddr("user");
    address public controller = makeAddr("controller");

    Registry public registry;
    ReverseRegistrarV2 public reverse;
    MockL2ReverseRegistrar public l2ReverseRegistrar;
    MockNameResolver public resolver;

    uint256 constant BASE_COINTYPE = 0x80000000 | 0x00002105;
    string name = "name";

    function setUp() public virtual {
        registry = new Registry(owner);
        l2ReverseRegistrar = new MockL2ReverseRegistrar();
        resolver = new MockNameResolver();
        reverse = new ReverseRegistrarV2(
            ENS(address(registry)), owner, BASE_REVERSE_NODE, address(l2ReverseRegistrar), BASE_COINTYPE
        );
        vm.prank(owner);
        reverse.setControllerApproval(controller, true);
        _registrySetup();
    }

    function _registrySetup() internal virtual {
        // establish the base.eth namespace
        bytes32 ethLabel = keccak256("eth");
        bytes32 baseLabel = keccak256("base");
        vm.prank(owner);
        registry.setSubnodeOwner(0x0, ethLabel, owner);
        vm.prank(owner);
        registry.setSubnodeOwner(ETH_NODE, baseLabel, owner);

        // establish the 80002105.reverse namespace
        vm.prank(owner);
        registry.setSubnodeOwner(0x0, keccak256("reverse"), owner);
        vm.prank(owner);
        registry.setSubnodeOwner(REVERSE_NODE, keccak256("80002105"), address(reverse));
    }
}
