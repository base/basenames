//SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {AttestationAccessControl} from "verifications/abstracts/AttestationAccessControl.sol";
import {AttestationVerifier} from "verifications/libraries/AttestationVerifier.sol";
import {IAttestationIndexer} from "verifications/interfaces/IAttestationIndexer.sol";
import {Ownable} from "solady/auth/Ownable.sol";

import {DiscountValidator} from "./DiscountValidator.sol";
import {SybilResistanceVerifier} from "src/lib/SybilResistanceVerifier.sol";

/// @title Discount Validator for: Coinbase Attestation Validator
///
/// @notice Implements a two step validation schema for verifying coinbase attestations
///         1. Verify that the wallet has an active Coinbase Verification for the stored `schemaID`.
///         2. Signature verification to valiate signatures from the Coinbase sybil resistance service.
///         https://github.com/coinbase/verifications
///
/// @author Coinbase (https://github.com/base-org/usernames)
contract AttestationValidator is Ownable, AttestationAccessControl, DiscountValidator {
    /// @dev The attestation service signer.
    address signer;

    /// @dev The EAS schema id for Coinbase Verified Accounts.
    bytes32 immutable schemaID;

    /// @notice Attestation Validator constructor
    ///
    /// @param owner_ The permissioned `owner` in the `Ownable` context.
    /// @param signer_ The off-chain signer of the Coinbase sybil resistance service.
    /// @param schemaID_ The EAS schema id associated with a specified verification.
    /// @param indexer_ The address of the Coinbase attestation indexer.
    constructor(address owner_, address signer_, bytes32 schemaID_, address indexer_) {
        _initializeOwner(owner_);
        signer = signer_;
        schemaID = schemaID_;
        _setIndexer(IAttestationIndexer(indexer_));
    }

    /// @notice Allows the owner to update the expected signer.
    ///
    /// @param signer_ The address of the new signer.
    function setSigner(address signer_) external onlyOwner {
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
    function isValidDiscountRegistration(address claimer, bytes calldata validationData) public override view returns (bool) {
        AttestationVerifier.verifyAttestation(_getAttestation(claimer, schemaID));

        return SybilResistanceVerifier.verifySignature(signer, claimer, validationData);
    }
}
