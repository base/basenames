// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {TalentProtocol} from "src/L2/discounts/TalentProtocolDiscountValidator.sol";

contract MockBuilderScorePassport is TalentProtocol {
    uint256 score;

    constructor(uint256 score_) {
        score = score_;
    }

    function getScoreByAddress(address) external view returns (uint256) {
        return score;
    }

    function setScore(uint256 score_) external {
        score = score_;
    }
}
