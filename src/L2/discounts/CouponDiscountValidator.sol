//SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {ECDSA} from "solady/utils/ECDSA.sol";
import {Ownable} from "solady/auth/Ownable.sol";

import {IDiscountValidator} from "src/L2/interface/IDiscountValidator.sol";

/// @title Discount Validator for: Coupons
///
/// @notice Implements a signature-based discount validation on unique coupon codes.
///
/// @author Coinbase (https://github.com/base-org/usernames)
contract CouponDiscountValidator is Ownable, IDiscountValidator {
    /// @notice Thrown when setting a critical address to the zero-address.
    error NoZeroAddress();

    /// @dev The coupon service signer.
    address signer;

    /// @notice Thrown when the signature expiry date < block.timestamp.
    error SignatureExpired();

    /// @notice Attestation Validator constructor
    ///
    /// @param owner_ The permissioned `owner` in the `Ownable` context.
    /// @param signer_ The off-chain signer of the Coinbase sybil resistance service.
    constructor(address owner_, address signer_) {
        if (signer_ == address(0)) revert NoZeroAddress();
        _initializeOwner(owner_);
        signer = signer_;
    }

    /// @notice Allows the owner to update the expected signer.
    ///
    /// @param signer_ The address of the new signer.
    function setSigner(address signer_) external onlyOwner {
        if (signer_ == address(0)) revert NoZeroAddress();
        signer = signer_;
    }

    /// @notice Required implementation for compatibility with IDiscountValidator.
    ///
    /// @dev The data must be encoded as `abi.encode(discountClaimerAddress, expiry, signature_bytes)`.
    ///
    /// @param validationData opaque bytes for performing the validation.
    ///
    /// @return `true` if the validation data provided is determined to be valid for the specified claimer, else `false`.
    function isValidDiscountRegistration(address claimer, bytes calldata validationData) external view returns (bool) {
        (uint64 expiry, bytes32 uuid, bytes memory sig) = abi.decode(validationData, (uint64, bytes32, bytes));
        if (expiry < block.timestamp) revert SignatureExpired();

        address returnedSigner = ECDSA.recover(_makeSignatureHash(claimer, uuid, expiry), sig);
        return returnedSigner == signer;
    }

    /// @notice  Generates a hash for signing/verifying.
    ///
    /// @dev The message hash should be dervied by: `keccak256(abi.encode(0x1900, trustedSignerAddress, discountClaimerAddress, couponUui, claimsPerUuid, expiry, salt))`.
    ///     Compliant with EIP-191 for `Data for intended validator`: https://eips.ethereum.org/EIPS/eip-191#version-0x00 .
    ///
    /// @param claimer Address of the coupon claimer.
    /// @param couponUuid The Uuid of the coupon.
    /// @param expires The date of the signature expiry.
    ///
    /// @return The EIP-191 compliant signature hash.
    function _makeSignatureHash(address claimer, bytes32 couponUuid, uint64 expires) internal view returns (bytes32) {
        return keccak256(abi.encodePacked(hex"1900", address(this), signer, claimer, couponUuid, expires));
    }
}
