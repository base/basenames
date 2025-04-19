//SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {TBADiscountValidator} from "src/L2/discounts/TBADiscountValidator.sol";
import {TBADiscountValidatorBase} from "./TBADiscountValidatorBase.t.sol";

contract IsValidDiscountRegistration is TBADiscountValidatorBase {
    function test_reverts_whenTheSignatureIsExpired() public {
        bytes memory expiredSignatureData = _getDefaultValidationData();
        vm.warp(expires + 1);
        vm.expectRevert(abi.encodeWithSelector(TBADiscountValidator.SignatureExpired.selector));
        validator.isValidDiscountRegistration(user, expiredSignatureData);
    }

    function test_returnsFalse_whenTheExpectedSignerMismatches(uint256 pk) public view {
        vm.assume(pk != signerPk && pk != 0 && pk < type(uint128).max);
        bytes32 digest = _makeSignatureHash(user, deviceId, expires);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(pk, digest);
        bytes memory sig = abi.encodePacked(r, s, v);
        bytes memory badSignerValidationData = abi.encode(deviceId, expires, sig);

        assertFalse(validator.isValidDiscountRegistration(user, badSignerValidationData));
    }

    function test_returnsTrue_whenEverythingIsHappy() public {
        assertTrue(validator.isValidDiscountRegistration(user, _getDefaultValidationData()));
    }
}
