// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;


contract MockL2ReverseRegistrar { 
    /// @notice Sets the `nameForAddr()` record for the addr provided account using a signature.
    ///
    /// @param addr The address to set the name for.
    /// @param name The name to set.
    /// @param coinTypes The coin types to set. Must be inclusive of the coin type for the contract.
    /// @param signatureExpiry Date when the signature expires.
    /// @param signature The signature from the addr.
    function setNameForAddrWithSignature(
        address addr,
        uint256 signatureExpiry,
        string memory name,
        uint256[] memory coinTypes,
        bytes memory signature
    ) external {}
}