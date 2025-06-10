// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {UpgradeableRegistrarControllerBase} from "./UpgradeableRegistrarControllerBase.t.sol";
import {IPriceOracle} from "src/L2/interface/IPriceOracle.sol";

contract RentPrice is UpgradeableRegistrarControllerBase {
    function test_returnsPrice_fromPricingOracle() public view {
        IPriceOracle.Price memory retPrices = controller.rentPrice(name, 0);
        assertEq(retPrices.base, prices.DEFAULT_BASE_WEI());
        assertEq(retPrices.premium, prices.DEFAULT_PREMIUM_WEI());
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
