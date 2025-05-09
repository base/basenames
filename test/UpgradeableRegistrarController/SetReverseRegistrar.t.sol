// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {UpgradeableRegistrarControllerBase} from "./UpgradeableRegistrarControllerBase.t.sol";
import {UpgradeableRegistrarController} from "src/L2/UpgradeableRegistrarController.sol";
import {MockReverseRegistrarV2} from "test/mocks/MockReverseRegistrarV2.sol";
import {IReverseRegistrarV2} from "src/L2/interface/IReverseRegistrarV2.sol";
import {OwnableUpgradeable} from "openzeppelin-contracts-upgradeable/access/OwnableUpgradeable.sol";

contract SetReverseRegistrar is UpgradeableRegistrarControllerBase {
    function test_reverts_ifCalledByNonOwner(address caller) public whenNotProxyAdmin(caller, address(controller)) {
        vm.assume(caller != owner);
        MockReverseRegistrarV2 newReverse = new MockReverseRegistrarV2();
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, caller));
        vm.prank(caller);
        controller.setReverseRegistrar(IReverseRegistrarV2(address(newReverse)));
    }

    function test_setsTheReverseRegistrarAccordingly() public {
        vm.expectEmit();
        MockReverseRegistrarV2 newReverse = new MockReverseRegistrarV2();
        emit UpgradeableRegistrarController.ReverseRegistrarUpdated(address(newReverse));
        vm.prank(owner);
        controller.setReverseRegistrar(IReverseRegistrarV2(address(newReverse)));
        assertEq(address(controller.reverseRegistrar()), address(newReverse));
    }
}
