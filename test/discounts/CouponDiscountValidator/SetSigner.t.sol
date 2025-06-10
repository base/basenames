//SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {CouponDiscountValidatorBase} from "./CouponDiscountValidatorBase.t.sol";
import {Ownable} from "solady/auth/Ownable.sol";

contract SetSigner is CouponDiscountValidatorBase {
    function test_reverts_whenCalledByNonOwner(address caller) public {
        vm.assume(caller != owner && caller != address(0));
        vm.expectRevert(Ownable.Unauthorized.selector);
        vm.prank(caller);
        validator.setSigner(caller);
    }

    function test_allowsTheOwner_toUpdateTheSigner() public {
        vm.prank(owner);
        address newSigner = makeAddr("new");
        validator.setSigner(newSigner);
    }
}
