//SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Test} from "forge-std/Test.sol";
import {TalentProtocolDiscountValidator} from "src/L2/discounts/TalentProtocolDiscountValidator.sol";
import {MockBuilderScorePassport} from "test/mocks/MockBuilderScorePassport.sol";

contract TalentProtocolDiscountValidatorBase is Test {
    MockBuilderScorePassport talent;
    TalentProtocolDiscountValidator validator;
    address owner = makeAddr("owner");
    address userA = makeAddr("userA");
    address userB = makeAddr("userB");

    uint256 threshold = 50;

    function setUp() public {
        talent = new MockBuilderScorePassport(threshold);
        validator = new TalentProtocolDiscountValidator(owner, address(talent), threshold);
    }
}
