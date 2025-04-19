//SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {IReverseRegistrar} from "./interface/IReverseRegistrar.sol";
import {IL2ReverseResolver} from "./interface/IL2ReverseResolver.sol";

contract ReverseRegistrarShim {
    address public immutable reverseRegistrar;
    address public immutable reverseResolver;
    address public immutable l2Resolver;

    constructor(address reverseRegistrar_, address reverseResolver_, address l2Resolver_) {
        reverseRegistrar = reverseRegistrar_;
        reverseResolver = reverseResolver_;
        l2Resolver = l2Resolver_;
    }

    function setNameForAddrWithSignature(
        address addr,
        string calldata name,
        uint256 signatureExpiry,
        bytes memory signature
    ) external returns (bytes32) {
        IReverseRegistrar(reverseRegistrar).setNameForAddr(addr, msg.sender, l2Resolver, name);
        return IL2ReverseResolver(reverseResolver).setNameForAddrWithSignature(addr, name, signatureExpiry, signature);
    }
}
