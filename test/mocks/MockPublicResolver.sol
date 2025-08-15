//SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {BASE_ETH_NODE} from "src/util/Constants.sol";
import {ExtendedResolver} from "ens-contracts/resolvers/profiles/ExtendedResolver.sol";
import {IAddrResolver} from "ens-contracts/resolvers/profiles/IAddrResolver.sol";
import {ITextResolver} from "ens-contracts/resolvers/profiles/ITextResolver.sol";

import "forge-std/console.sol";

contract MockPublicResolver is ExtendedResolver {
    mapping(bytes32 => address) addrs;
    mapping(bytes32 => mapping(string => string)) texts;
    address public constant ADDRESS = 0x000000000000000000000000000000000000dEaD;
    string public constant TEST_TEXT = "pass";
    bytes public firstBytes;

    constructor() {
        addrs[BASE_ETH_NODE] = ADDRESS;
        texts[BASE_ETH_NODE]["test"] = TEST_TEXT;
    }

    function addr(bytes32 node) external view returns (address) {
        return addrs[node];
    }

    function text(bytes32 node, string calldata key) external view returns (string memory) {
        return texts[node][key];
    }

    function multicallWithNodeCheck(bytes32, bytes[] memory data) external returns (bytes[] memory results) {
        firstBytes = data[0];
        return data;
    }

    function supportsInterface(bytes4 interfaceID) public pure returns (bool) {
        return interfaceID == type(IAddrResolver).interfaceId || interfaceID == type(ITextResolver).interfaceId;
    }
}
