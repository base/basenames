// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {SignatureChecker} from "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";
import {console} from "forge-std/console.sol";

/// @notice Represents an association between two accounts.
struct AssociatedAccountRecord {
    /// @dev The address of the initiating account.
    address initiator;
    /// @dev The address of the approving account
    address approver;
    /// @dev Optional additional data.
    bytes data;
}

/// @notice Helper struct for sharing a signed association.
struct SignedAssociationRecord {
    /// @dev The signature of the initiator.
    bytes initiatorSignature;
    /// @dev The signature of the approver.
    bytes approverSignature;
    /// @dev The signed AssociatedAccountRecord.
    AssociatedAccountRecord record;
}

/// @notice Helper Lib for creating, signing and validating AssociatedAccount records and the resulting
///     SignedAssociationRecords.
library AssociatedAccountsLib {
    /// @dev Precomputed `typeHash` used to produce EIP-712 compliant hash.
    ///      The original hash must be:
    ///         - An EIP-712 hash: keccak256("\x19\x01" || someDomainSeparator || hashStruct(someStruct))
    bytes32 private constant _MESSAGE_TYPEHASH =
        keccak256("AssociatedAccountRecord(address initiator, address approver, bytes data)");

    /// @notice Helper for validating the contents of a SignedAssociationRecord.
    function validateAssociatedAccount(SignedAssociationRecord memory sar) external view returns (bool) {
        bytes32 hash = eip712Hash(sar.record);
        return _isValidSignature(hash, sar.record.approver, sar.approverSignature)
            && _isValidSignature(hash, sar.record.initiator, sar.initiatorSignature);
    }

    /// @notice Returns the `domainSeparator` used to create EIP-712 compliant hashes.
    ///
    /// @dev Implements domainSeparator = hashStruct(eip712Domain).
    ///      See https://eips.ethereum.org/EIPS/eip-712#definition-of-domainseparator.
    ///
    /// @return The 32 bytes domain separator result.
    function domainSeparator() public pure returns (bytes32) {
        (string memory name, string memory version) = _domainNameAndVersion();
        return keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version)"), keccak256(bytes(name)), keccak256(bytes(version))
            )
        );
    }

    /// @notice Helper for generating the association uuid for a given `aar`.
    ///
    /// @dev The keccak256 hash of the encoding of the two addresses `initiator` and `approver`,
    ///     with the eip-712 domainSeparator. 
    function uuidFromAAR(AssociatedAccountRecord memory aar) public pure returns (bytes32) {
        return keccak256(abi.encode(
            aar.initiator, aar.approver, domainSeparator()
        ));
    }

    /// @notice Helper for generating the association uuid for a given `sar`.
    ///
    /// @dev The keccak256 hash of the encoding of the two addresses `initiator` and `approver`,
    ///     with the eip-712 domainSeparator. 
    function uuidFromSAR(SignedAssociationRecord memory sar) public pure returns (bytes32) {
        return uuidFromAAR(sar.record);
    }

    /// @notice Helper for fetching the EIP-712 signature hash for a provided AssociatedAccountRecord.
    function eip712Hash(AssociatedAccountRecord memory aar) public pure returns (bytes32) {
        return _eip712Hash(aar.initiator, aar.approver, aar.data);
    }

    /// @notice Returns the domain name and version to use when creating EIP-712 signatures.
    ///
    /// @dev MUST be defined by the implementation.
    ///
    /// @return name    The user readable name of signing domain.
    /// @return version The current major version of the signing domain.
    function _domainNameAndVersion() internal pure returns (string memory name, string memory version) {
        return ("AssociatedAccount", "1");
    }

    /// @notice Validates the `signature` against the given `hash`.
    ///
    /// @dev MUST be defined by the implementation.
    ///
    /// @return `true` is the signature is valid, else `false`.
    function _isValidSignature(bytes32 hash, address signer, bytes memory signature) internal view returns (bool) {
        return SignatureChecker.isValidSignatureNow(signer, hash, signature);
    }

    /// @notice Returns the EIP-712 typed hash of the `AssociatedAccountRecord(address account, bytes data)` data structure.
    ///
    /// @dev Implements encode(domainSeparator : 𝔹²⁵⁶, message : 𝕊) = "\x19\x01" || domainSeparator ||
    ///      hashStruct(message).
    /// @dev See https://eips.ethereum.org/EIPS/eip-712#specification.
    ////
    /// @return The resulting EIP-712 hash.
    function _eip712Hash(address initiator, address approver, bytes memory data) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked("\x19\x01", domainSeparator(), _hashStruct(initiator, approver, data)));
    }

    /// @notice Returns the EIP-712 `hashStruct` result of the `AssociatedAccountRecord(address account, bytes data)` data
    ///         structure.
    ///
    /// @dev Implements hashStruct(s : 𝕊) = keccak256(typeHash || encodeData(s)).
    /// @dev See https://eips.ethereum.org/EIPS/eip-712#definition-of-hashstruct.
    ///
    /// @return The EIP-712 `hashStruct` result.
    function _hashStruct(address initiator, address approver, bytes memory data) internal pure returns (bytes32) {
        return keccak256(abi.encode(_MESSAGE_TYPEHASH, initiator, approver, keccak256(data)));
    }
}
