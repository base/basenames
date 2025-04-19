// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

interface IL2ReverseResolver {
    /**
     * @dev Sets the name for an addr using a signature that can be verified with ERC1271.
     * @param addr The reverse record to set
     * @param name The name of the reverse record
     * @param signatureExpiry Date when the signature expires
     * @param signature The resolver of the reverse node
     * @return The ENS node hash of the reverse record.
     */
    function setNameForAddrWithSignature(
        address addr,
        string calldata name,
        uint256 signatureExpiry,
        bytes memory signature
    ) external returns (bytes32);
}
