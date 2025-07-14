// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

contract MockL2ReverseRegistrar {
    bool public hasClaimed;

    function setNameForAddrWithSignature(address, uint256, string memory, uint256[] memory, bytes memory) external {
        hasClaimed = true;
    }
}
