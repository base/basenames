//SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {CouponDiscountValidator} from "src/L2/discounts/CouponDiscountValidator.sol";
import {CouponDiscountValidatorBase} from "./CouponDiscountValidatorBase.t.sol";

contract IsValidDiscountRegistration is CouponDiscountValidatorBase {
    function test_reverts_whenTheSignatureIsExpired() public {
        bytes memory validationData = _getDefaultValidationData();
        (, bytes32 _uuid, bytes memory sig) = abi.decode(validationData, (uint64, bytes32, bytes));
        bytes memory expiredSignatureData = abi.encode((block.timestamp - 1), _uuid, sig);

        vm.expectRevert(abi.encodeWithSelector(CouponDiscountValidator.SignatureExpired.selector));
        validator.isValidDiscountRegistration(user, expiredSignatureData);
    }

    function test_returnsFalse_whenTheExpectedSignerMismatches(uint256 pk) public view {
        vm.assume(pk != signerPk && pk != 0 && pk < type(uint128).max);
        bytes32 digest = _makeSignatureHash(user, uuid, expires);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(pk, digest);
        bytes memory sig = abi.encodePacked(r, s, v);
        bytes memory badSignerValidationData = abi.encode(expires, uuid, sig);

        assertFalse(validator.isValidDiscountRegistration(user, badSignerValidationData));
    }

    function test_returnsTrue_whenEverythingIsHappy() public {
        assertTrue(validator.isValidDiscountRegistration(user, _getDefaultValidationData()));
    }
}
