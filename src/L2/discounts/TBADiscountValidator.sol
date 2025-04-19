//SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {ECDSA} from "solady/utils/ECDSA.sol";

import {IDiscountValidator} from "src/L2/interface/IDiscountValidator.sol";

/// @title Discount Validator for: TBA
///
/// @notice Implements a signature-based discount validation.
///
/// @author Coinbase (https://github.com/base-org/usernames)
contract TBADiscountValidator is IDiscountValidator {
    /// @notice Thrown when setting a critical address to the zero-address.
    error NoZeroAddress();

    /// @notice Thrown when the signature expiry date < block.timestamp.
    error SignatureExpired();

    /// @dev The sybil resistance service signer.
    address immutable signer;

    /// @notice constructor
    ///
    /// @param signer_ The off-chain signer of the Coinbase sybil resistance service.
    constructor(address signer_) {
        if (signer_ == address(0)) revert NoZeroAddress();
        signer = signer_;
    }

    /// @notice Required implementation for compatibility with IDiscountValidator.
    ///
    /// @dev The data must be encoded as `abi.encode(keccak256(deviceId), expiry, signature_bytes)`.
    ///
    /// @param validationData opaque bytes for performing the validation.
    ///
    /// @return `true` if the validation data provided is determined to be valid for the specified claimer, else `false`.
    function isValidDiscountRegistration(address claimer, bytes calldata validationData) external view returns (bool) {
        (bytes32 deviceId, uint64 expiry, bytes memory sig) = abi.decode(validationData, (bytes32, uint64, bytes));
        if (expiry < block.timestamp) revert SignatureExpired();

        address returnedSigner = ECDSA.recover(_makeSignatureHash(claimer, deviceId, expiry), sig);
        return returnedSigner == signer;
    }

    /// @notice  Generates a hash for signing/verifying.
    ///
    /// @dev The message hash should be derived by: `keccak256(abi.encode(0x1900, validatorAddress, claimerAddress, deviceId, expiry))`.
    ///     Compliant with EIP-191 for `Data for intended validator`: https://eips.ethereum.org/EIPS/eip-191#version-0x00 .
    ///
    /// @param claimer Address of the coupon claimer.
    /// @param deviceId The keccak256 hash of the device ID.
    /// @param expires The date of the signature expiry.
    ///
    /// @return The EIP-191 compliant signature hash.
    function _makeSignatureHash(address claimer, bytes32 deviceId, uint64 expires) internal view returns (bytes32) {
        return keccak256(abi.encodePacked(hex"1900", address(this), claimer, deviceId, expires));
    }
}
