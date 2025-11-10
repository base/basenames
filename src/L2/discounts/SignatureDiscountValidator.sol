//SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Ownable} from "solady/auth/Ownable.sol";

import {IDiscountValidator} from "src/L2/interface/IDiscountValidator.sol";
import {SybilResistanceVerifier} from "src/lib/SybilResistanceVerifier.sol";

/// @title Discount Validator for: Signature Discount Validator
///
/// @notice Implements a simple signature validation schema which performs signature verification to validate
///         signatures were generated from the Base Signer Service.
///
/// @author Coinbase (https://github.com/base-org/basenames)
contract SignatureDiscountValidator is Ownable, IDiscountValidator {
    /// @dev The Base Signer Service signer address.
    address signer;

    /// @dev Thrown when setting the zero address as `owner` or `signer`.
    error NoZeroAddress();

    /// @notice constructor
    ///
    /// @param owner_ The permissioned `owner` in the `Ownable` context.
    /// @param signer_ The off-chain signer of the Base Signer Service.
    constructor(address owner_, address signer_) {
        if (owner_ == address(0)) revert NoZeroAddress();
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
    /// @param claimer the discount claimer's address.
    /// @param validationData opaque bytes for performing the validation.
    ///
    /// @return `true` if the validation data provided is determined to be valid for the specified claimer, else `false`.
    function isValidDiscountRegistration(address claimer, bytes calldata validationData) external view returns (bool) {
        return SybilResistanceVerifier.verifySignature(signer, claimer, validationData);
    }
}
