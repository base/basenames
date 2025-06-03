// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

contract MockRegistrarController {
    mapping(address => bool) hasRegistered;
    uint256 public launchTime;

    mapping(address => bool) public discountedRegistrants;

    constructor(uint256 launchTime_) {
        launchTime = launchTime_;
    }

    function hasRegisteredWithDiscount(address[] memory addresses) external view returns (bool) {
        for (uint256 i; i < addresses.length; i++) {
            if (hasRegistered[addresses[i]]) {
                return true;
            }
        }
        return false;
    }

    function setHasRegisteredWithDiscount(address addr, bool status) external {
        hasRegistered[addr] = status;
        discountedRegistrants[addr] = status;
    }
}
