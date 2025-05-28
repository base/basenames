// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {UpgradeableRegistrarControllerBase} from "./UpgradeableRegistrarControllerBase.t.sol";
import {RegistrarController} from "src/L2/RegistrarController.sol";
import {IPriceOracle} from "src/L2/interface/IPriceOracle.sol";

contract DiscountedRegisterPrice is UpgradeableRegistrarControllerBase {
    function test_returnsADiscountedPrice_whenThePriceIsGreaterThanTheDiscount(uint256 price) public {
        vm.assume(price > discountAmount);
        prices.setPrice(name, IPriceOracle.Price({base: price, premium: 0}));
        vm.prank(owner);
        controller.setDiscountDetails(_getDefaultDiscount());

        uint256 expectedPrice = price - discountAmount;
        uint256 retPrice = controller.discountedRegisterPrice(name, duration, discountKey);
        assertEq(retPrice, expectedPrice);
    }

    function test_returnsZero_whenThePriceIsLessThanOrEqualToTheDiscount(uint256 price) public {
        vm.assume(price > 0 && price <= discountAmount);
        prices.setPrice(name, IPriceOracle.Price({base: price, premium: 0}));
        vm.prank(owner);
        controller.setDiscountDetails(_getDefaultDiscount());

        uint256 retPrice = controller.discountedRegisterPrice(name, duration, discountKey);
        assertEq(retPrice, 0);
    }
}
