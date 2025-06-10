//SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {AddrResolver} from "ens-contracts/resolvers/profiles/AddrResolver.sol";

contract MockAddrResolver is AddrResolver {
    function isAuthorised(bytes32) internal pure override returns (bool) {
        return true;
    }
}
