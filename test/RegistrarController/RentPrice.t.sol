// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {RegistrarControllerBase} from "./RegistrarControllerBase.t.sol";
import {IPriceOracle} from "src/L2/interface/IPriceOracle.sol";

contract RentPrice is RegistrarControllerBase {
    function test_returnsPrice_fromPricingOracle() public view {
        IPriceOracle.Price memory retPrices = controller.rentPrice(name, 0);
        assertEq(retPrices.base, prices.DEFAULT_BASE_WEI());
        assertEq(retPrices.premium, prices.DEFAULT_PERMIUM_WEI());
    }

    function test_returnsPremium_ifTimeIsNearLaunchTime() public {
        vm.prank(owner);
        controller.setLaunchTime(launchTime);

        vm.warp(launchTime + 1);
        IPriceOracle.Price memory retPrices = controller.rentPrice(name, 0);
        assertEq(retPrices.base, prices.DEFAULT_BASE_WEI());
        assertEq(retPrices.premium, prices.DEFAULT_INCLUDED_PREMIUM());
    }

    function test_fuzz_returnsPrice_fromPricingOracle(uint256 fuzzBase, uint256 fuzzPremium) public {
        vm.assume(fuzzBase != 0 && fuzzBase < type(uint128).max);
        vm.assume(fuzzPremium < type(uint128).max);
        IPriceOracle.Price memory expectedPrice = IPriceOracle.Price({base: fuzzBase, premium: fuzzPremium});
        prices.setPrice(name, expectedPrice);
        IPriceOracle.Price memory retPrices = controller.rentPrice(name, 0);
        assertEq(retPrices.base, expectedPrice.base);
        assertEq(retPrices.premium, expectedPrice.premium);
    }
}
