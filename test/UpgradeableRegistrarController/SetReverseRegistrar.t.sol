// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {UpgradeableRegistrarControllerBase} from "./UpgradeableRegistrarControllerBase.t.sol";
import {UpgradeableRegistrarController} from "src/L2/UpgradeableRegistrarController.sol";
import {MockReverseRegistrar} from "test/mocks/MockReverseRegistrar.sol";
import {IReverseRegistrar} from "src/L2/interface/IReverseRegistrar.sol";
import {OwnableUpgradeable} from "openzeppelin-contracts-upgradeable/access/OwnableUpgradeable.sol";

contract SetReverseRegistrar is UpgradeableRegistrarControllerBase {
    function test_reverts_ifCalledByNonOwner(address caller) public whenNotProxyAdmin(caller, address(controller)) {
        vm.assume(caller != owner);
        MockReverseRegistrar newReverse = new MockReverseRegistrar();
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, caller));
        vm.prank(caller);
        controller.setReverseRegistrar(IReverseRegistrar(address(newReverse)));
    }

    function test_setsTheReverseRegistrarAccordingly() public {
        vm.expectEmit();
        MockReverseRegistrar newReverse = new MockReverseRegistrar();
        emit UpgradeableRegistrarController.ReverseRegistrarUpdated(address(newReverse));
        vm.prank(owner);
        controller.setReverseRegistrar(IReverseRegistrar(address(newReverse)));
        assertEq(address(controller.reverseRegistrar()), address(newReverse));
    }
}
