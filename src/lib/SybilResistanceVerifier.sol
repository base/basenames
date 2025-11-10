//SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {ECDSA} from "solady/utils/ECDSA.sol";

/// @title Sybil Resistance Verifier
///
/// @notice A library for validating signed verifications from the Coinbase Sybil Resistance service.
///
/// @author Coinbase (https://github.com/base-org/usernames)
library SybilResistanceVerifier {
    /// @notice Thrown when the address for the claimer recovered from `validationData` does not match the address passed
    ///         to the validator.
    ///
    /// @param expectedClaimer The address packed in `validationData` as the expected claimer.
    /// @param claimer The address that is calling the discounted registration.
    error ClaimerAddressMismatch(address expectedClaimer, address claimer);

    /// @notice Thrown when the signature expiry date < block.timestamp.
    error SignatureExpired();

    /// @notice  Generates a hash for signing/verifying.
    ///
    /// @dev The message hash should be dervied by: `keccak256(abi.encode(0x1900, trustedSignerAddress, discountClaimerAddress, expiry))`.
    ///     Compliant with EIP-191 for `Data for intended validator`: https://eips.ethereum.org/EIPS/eip-191#version-0x00 .
    ///
    /// @param target The address of the on-chain signature verifier.
    /// @param claimer The address of the claimer.
    /// @param expires The date of signature expiry.
    function _makeSignatureHash(address target, address signer, address claimer, uint64 expires)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(abi.encodePacked(hex"1900", target, signer, claimer, expires));
    }

    /// @notice Verifies that the signature provided matches the expected signer.
    ///
    /// @param signer The address of the expected signer.
    /// @param claimer The address of the address being verified by the sybil resistance service.
    /// @param validationData Encoded bytes containing: `abi.encode(discountClaimerAddress, expiry, signature_bytes)`
    function verifySignature(address signer, address claimer, bytes calldata validationData)
        internal
        view
        returns (bool)
    {
        (address expectedClaimer, uint64 expires, bytes memory sig) =
            abi.decode(validationData, (address, uint64, bytes));

        if (expectedClaimer != claimer) revert ClaimerAddressMismatch(expectedClaimer, claimer);
        if (expires < block.timestamp) revert SignatureExpired();
        address recoveredSigner = ECDSA.recover(_makeSignatureHash(address(this), signer, claimer, expires), sig);
        return (recoveredSigner == signer);
    }
}
