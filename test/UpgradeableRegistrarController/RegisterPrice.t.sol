// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {UpgradeableRegistrarControllerBase} from "./UpgradeableRegistrarControllerBase.t.sol";
import {IPriceOracle} from "src/L2/interface/IPriceOracle.sol";

contract RegisterPrice is UpgradeableRegistrarControllerBase {
    function test_returnsRegisterPrice_fromPricingOracle() public view {
        uint256 retPrice = controller.registerPrice(name, duration);
        assertEq(retPrice, prices.DEFAULT_BASE_WEI() + prices.DEFAULT_PREMIUM_WEI());
    }

    function test_fuzz_returnsRegisterPrice_fromPricingOracle(uint256 fuzzBase, uint256 fuzzPremium) public {
        vm.assume(fuzzBase != 0 && fuzzBase < type(uint128).max);
        vm.assume(fuzzPremium < type(uint128).max);
        IPriceOracle.Price memory expectedPrice = IPriceOracle.Price({base: fuzzBase, premium: fuzzPremium});
        prices.setPrice(name, expectedPrice);
        uint256 retPrice = controller.registerPrice(name, 0);
        assertEq(retPrice, expectedPrice.base + expectedPrice.premium);
    }
}
