// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {UpgradeableRegistrarControllerBase} from "./UpgradeableRegistrarControllerBase.t.sol";
import {UpgradeableRegistrarController} from "src/L2/UpgradeableRegistrarController.sol";
import {OwnableUpgradeable} from "openzeppelin-contracts-upgradeable/access/OwnableUpgradeable.sol";

contract SetPaymentReceiver is UpgradeableRegistrarControllerBase {
    function test_reverts_ifCalledByNonOwner(address caller) public whenNotProxyAdmin(caller, address(controller)) {
        vm.assume(caller != owner && caller != address(0));
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, caller));
        vm.prank(caller);
        controller.setPaymentReceiver(caller);
    }

    function test_reverts_ifNewPaymentReceiver_isZeroAddress() public {
        vm.expectRevert(UpgradeableRegistrarController.InvalidPaymentReceiver.selector);
        vm.prank(owner);
        controller.setPaymentReceiver(address(0));
    }

    function test_allowsTheOwner_toSetThePaymentReceiver(address newReceiver) public {
        vm.assume(newReceiver != address(0));
        vm.expectEmit(address(controller));
        emit UpgradeableRegistrarController.PaymentReceiverUpdated(newReceiver);
        vm.prank(owner);
        controller.setPaymentReceiver(newReceiver);
        assertEq(newReceiver, controller.paymentReceiver());
    }
}
