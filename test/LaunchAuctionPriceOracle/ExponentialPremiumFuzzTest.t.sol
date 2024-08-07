//SPDX-License-Identifier: MIT
pragma solidity ~0.8.17;

import {Test, console} from "forge-std/Test.sol";
import {LaunchAuctionPriceOracleBase} from "./LaunchAuctionPriceOracleBase.t.sol";
import {FixedPointMathLib} from "solady/utils/FixedPointMathLib.sol";

contract ExponentialPremiumFuzzTest is LaunchAuctionPriceOracleBase {
    function test_decayedPremium_decreasingPrices(uint256 elapsed) public view {
        elapsed = bound(elapsed, 0, totalDays * 1 days);
        uint256 actualPremium = oracle.decayedPremium(elapsed);
        assert(actualPremium <= startPremium);
    }

    function test_decayedPremium_alwaysDecreasing(uint256 elapsed1, uint256 elapsed2) public view {
        vm.assume(elapsed1 < elapsed2 && (elapsed1 < totalDays * 1 days));
        elapsed1 = bound(elapsed1, 0, elapsed2);
        elapsed2 = bound(elapsed2, elapsed1, totalDays * 1 days);

        uint256 premium1 = oracle.decayedPremium(elapsed1);
        uint256 premium2 = oracle.decayedPremium(elapsed2);

        assert(premium1 >= premium2);
    }
}
