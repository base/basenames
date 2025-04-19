//SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

contract MockReverseResolver {
    function setNameForAddrWithSignature(address, string calldata, uint256, bytes memory)
        external
        view
        returns (bytes32)
    {
        return bytes32(block.timestamp);
    }
}
