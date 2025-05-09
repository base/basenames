// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

contract MockReverseRegistrarV2 {
    struct MockReverseRecord {
        address addr;
        string name;
    }

    mapping(address => bool) public hasClaimed;
    MockReverseRecord public record;

    function claim(address claimant) external {
        hasClaimed[claimant] = true;
    }

    function setNameForAddrWithSignature(address addr, uint256, string calldata name, uint256[] memory, bytes memory)
        external
        returns (bytes32)
    {
        record = MockReverseRecord({addr: addr, name: name});
        hasClaimed[addr] = true;
        return bytes32(0);
    }
}
