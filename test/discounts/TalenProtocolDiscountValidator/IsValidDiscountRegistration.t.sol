//SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {TalentProtocolDiscountValidatorBase} from "./TalentProtocolDiscountValidatorBase.t.sol";

contract IsValidDiscountRegistration is TalentProtocolDiscountValidatorBase {
    function test_returnsTrue_whenTheScoreMeetsTheThreshold() public {
        talent.setScore(threshold);
        bool ret = validator.isValidDiscountRegistration(userA, "");
        assertTrue(ret);
    }

    function test_returnsTrue_whenTheScoreExceedsTheThreshold() public {
        talent.setScore(threshold + 1);
        bool ret = validator.isValidDiscountRegistration(userA, "");
        assertTrue(ret);
    }

    function test_returnsFalse_whenTheScoreIsBelowTheThreshold() public {
        talent.setScore(threshold - 1);
        bool ret = validator.isValidDiscountRegistration(userA, "");
        assertFalse(ret);
    }
}
