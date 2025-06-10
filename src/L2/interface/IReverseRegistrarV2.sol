// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

/// @title Interface for ReverseRegistrarV2
interface IReverseRegistrarV2 {
    /// @notice Transfers ownership of the base-specific reverse ENS record for `msg.sender` to the provided `owner`.
    ///
    /// @param owner The address to set as the owner of the reverse record in ENS.
    ///
    /// @return The ENS node hash of the Base network-specific reverse record.
    function claim(address owner) external returns (bytes32);

    /// @notice Sets the reverse record `name` for `addr`.
    ///
    /// @param addr The name records will be set for this address.
    /// @param signatureExpiry The timestamp expiration of the signature.
    /// @param name The name that will be stored for `addr`.
    /// @param cointypes The array of networks-as-cointypes used in replayable reverse sets.
    /// @param signature The signature bytes.
    function setNameForAddrWithSignature(
        address addr,
        uint256 signatureExpiry,
        string calldata name,
        uint256[] memory cointypes,
        bytes memory signature
    ) external returns (bytes32);
}
