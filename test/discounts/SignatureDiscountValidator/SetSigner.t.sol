//SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {SignatureDiscountValidator} from "src/L2/discounts/SignatureDiscountValidator.sol";
import {SignatureDiscountValidatorBase} from "./SignatureDiscountValidatorBase.t.sol";
import {Ownable} from "solady/auth/Ownable.sol";

contract SetSigner is SignatureDiscountValidatorBase {
    function test_reverts_whenCalledByNonOwner(address caller) public {
        vm.assume(caller != owner && caller != address(0));
        vm.expectRevert(Ownable.Unauthorized.selector);
        vm.prank(caller);
        validator.setSigner(caller);
    }

    function test_allowsTheOwner_toUpdateTheSigner(address newSigner) public {
        vm.assume(newSigner != signer && newSigner != address(0));
        vm.prank(owner);
        validator.setSigner(newSigner);
    }

    function test_revertWhen_settingSignerToZeroAddress() public {
        vm.expectRevert(SignatureDiscountValidator.NoZeroAddress.selector);
        vm.prank(owner);
        validator.setSigner(address(0));
    }
}
