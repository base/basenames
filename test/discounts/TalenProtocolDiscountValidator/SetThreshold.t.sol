//SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Ownable} from "solady/auth/Ownable.sol";
import {TalentProtocolDiscountValidatorBase} from "./TalentProtocolDiscountValidatorBase.t.sol";

contract SetThreshold is TalentProtocolDiscountValidatorBase {
    function test_reverts_whenCalledByNonOwner() public {
        vm.prank(userA);
        vm.expectRevert(abi.encodeWithSelector(Ownable.Unauthorized.selector));
        validator.setThreshold(0);
    }

    function test_allowsOwnerToSetThreshold() public {
        vm.prank(owner);
        validator.setThreshold(1);
        assertEq(1, validator.threshold());
    }
}
