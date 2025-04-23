//SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {IReverseRegistrar} from "./interface/IReverseRegistrar.sol";
import {IL2ReverseRegistrar} from "./interface/IL2ReverseRegistrar.sol";

contract ReverseRegistrarShim {
    address public immutable reverseRegistrar;
    address public immutable l2ReverseRegistrar;
    address public immutable l2Resolver;

    constructor(address reverseRegistrar_, address l2ReverseRegistrar_, address l2Resolver_) {
        reverseRegistrar = reverseRegistrar_;
        l2ReverseRegistrar = l2ReverseRegistrar_;
        l2Resolver = l2Resolver_;
    }

    function setNameForAddrWithSignature(
        address addr,
        string calldata name,
        uint256 signatureExpiry,
        uint256[] memory cointypes,
        bytes memory signature
    ) external returns (bytes32) {
        IL2ReverseRegistrar(l2ReverseRegistrar).setNameForAddrWithSignature(addr, signatureExpiry, name, cointypes, signature);
        return  IReverseRegistrar(reverseRegistrar).setNameForAddr(addr, msg.sender, l2Resolver, name);

    }
}
