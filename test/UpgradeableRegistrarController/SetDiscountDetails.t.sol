// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {UpgradeableRegistrarControllerBase} from "./UpgradeableRegistrarControllerBase.t.sol";
import {UpgradeableRegistrarController} from "src/L2/UpgradeableRegistrarController.sol";
import {OwnableUpgradeable} from "openzeppelin-contracts-upgradeable/access/OwnableUpgradeable.sol";

contract SetDiscountDetails is UpgradeableRegistrarControllerBase {
    function test_reverts_ifCalledByNonOwner(address caller) public whenNotProxyAdmin(caller, address(controller)) {
        vm.assume(caller != owner);
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, caller));
        vm.prank(caller);
        controller.setDiscountDetails(_getDefaultDiscount());
    }

    function test_reverts_ifTheDiscountIsZero() public {
        UpgradeableRegistrarController.DiscountDetails memory noDiscount = _getDefaultDiscount();
        noDiscount.discount = 0;
        vm.expectRevert(
            abi.encodeWithSelector(UpgradeableRegistrarController.InvalidDiscountAmount.selector, discountKey)
        );
        vm.prank(owner);
        controller.setDiscountDetails(noDiscount);
    }

    function test_reverts_ifTheDiscounValidatorIsInvalid() public {
        UpgradeableRegistrarController.DiscountDetails memory noValidator = _getDefaultDiscount();
        noValidator.discountValidator = address(0);
        vm.expectRevert(
            abi.encodeWithSelector(UpgradeableRegistrarController.InvalidValidator.selector, discountKey, address(0))
        );
        vm.prank(owner);
        controller.setDiscountDetails(noValidator);
    }

    function test_setsTheDetailsAccordingly() public {
        vm.expectEmit(address(controller));
        emit UpgradeableRegistrarController.DiscountUpdated(discountKey, _getDefaultDiscount());
        vm.prank(owner);
        controller.setDiscountDetails(_getDefaultDiscount());
        UpgradeableRegistrarController.DiscountDetails memory discount = controller.discounts(discountKey);
        assertTrue(discount.active);
        assertEq(discount.discountValidator, address(validator));
        assertEq(discount.key, discountKey);
        assertEq(discount.discount, discountAmount);
    }

    function test_addsAndRemoves_fromActiveDiscounts() public {
        UpgradeableRegistrarController.DiscountDetails memory discountDetails = _getDefaultDiscount();

        vm.prank(owner);
        controller.setDiscountDetails(discountDetails);
        UpgradeableRegistrarController.DiscountDetails[] memory activeDiscountsWithActive =
            controller.getActiveDiscounts();
        assertEq(activeDiscountsWithActive.length, 1);
        assertTrue(activeDiscountsWithActive[0].active);
        assertEq(activeDiscountsWithActive[0].discountValidator, address(validator));
        assertEq(activeDiscountsWithActive[0].key, discountKey);
        assertEq(activeDiscountsWithActive[0].discount, discountAmount);

        discountDetails.active = false;
        vm.prank(owner);
        controller.setDiscountDetails(discountDetails);
        UpgradeableRegistrarController.DiscountDetails[] memory activeDiscountsNoneActive =
            controller.getActiveDiscounts();
        assertEq(activeDiscountsNoneActive.length, 0);
    }
}
