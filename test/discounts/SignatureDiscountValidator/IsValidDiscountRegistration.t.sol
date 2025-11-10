//SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {SignatureDiscountValidatorBase} from "./SignatureDiscountValidatorBase.t.sol";
import {SybilResistanceVerifier} from "src/lib/SybilResistanceVerifier.sol";

contract IsValidDiscountRegistration is SignatureDiscountValidatorBase {
    function test_reverts_whenTheValidationData_claimerAddressMismatch(address notUser) public {
        vm.assume(notUser != user && notUser != address(0));
        bytes memory validationData = _getDefaultValidationData();
        (, uint64 expires, bytes memory sig) = abi.decode(validationData, (address, uint64, bytes));
        bytes memory claimerMismatchValidationData = abi.encode(notUser, expires, sig);

        vm.expectRevert(abi.encodeWithSelector(SybilResistanceVerifier.ClaimerAddressMismatch.selector, notUser, user));
        validator.isValidDiscountRegistration(user, claimerMismatchValidationData);
    }

    function test_reverts_whenTheValidationData_signatureIsExpired() public {
        bytes memory validationData = _getDefaultValidationData();
        (address expectedClaimer,, bytes memory sig) = abi.decode(validationData, (address, uint64, bytes));
        bytes memory claimerMismatchValidationData = abi.encode(expectedClaimer, (block.timestamp - 1), sig);

        vm.expectRevert(abi.encodeWithSelector(SybilResistanceVerifier.SignatureExpired.selector));
        validator.isValidDiscountRegistration(user, claimerMismatchValidationData);
    }

    function test_returnsFalse_whenTheExpectedSignerMismatches(uint256 pk) public view {
        vm.assume(pk != signerPk && pk != 0 && pk < type(uint128).max);
        address badSigner = vm.addr(pk);
        bytes32 digest = SybilResistanceVerifier._makeSignatureHash(address(validator), badSigner, user, expires);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(pk, digest);
        bytes memory sig = abi.encodePacked(r, s, v);
        bytes memory badSignerValidationData = abi.encode(user, expires, sig);

        assertFalse(validator.isValidDiscountRegistration(user, badSignerValidationData));
    }

    function test_returnsTrue_whenEverythingIsHappy() public {
        assertTrue(validator.isValidDiscountRegistration(user, _getDefaultValidationData()));
    }
}
