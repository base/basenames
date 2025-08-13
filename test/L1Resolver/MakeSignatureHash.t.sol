//SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Test, console} from "forge-std/Test.sol";
import {L1ResolverTestBase} from "./L1ResolverBase.t.sol";

import {L1Resolver} from "src/L1/L1Resolver.sol";
import {Ownable} from "solady/auth/Ownable.sol";
import {SignatureVerifier} from "src/lib/SignatureVerifier.sol";

contract MakeSignatureHash is L1ResolverTestBase {
    function test_makesValidSignatureHash(address target, uint64 expires, bytes memory request, bytes memory result)
        public
        view
    {
        bytes32 expectedHash = SignatureVerifier.makeSignatureHash(target, expires, request, result);
        bytes32 testHash = resolver.makeSignatureHash(target, expires, request, result);
        assertEq(expectedHash, testHash);
    }
}
