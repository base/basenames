//SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Test, console} from "forge-std/Test.sol";
import {L1ResolverTestBase} from "./L1ResolverBase.t.sol";

import {L1Resolver} from "src/L1/L1Resolver.sol";
import {Ownable} from "solady/auth/Ownable.sol";
import {SignatureVerifier} from "src/lib/SignatureVerifier.sol";
import {ECDSA} from "solady/utils/ECDSA.sol";
import {BASE_ETH_NAME, BASE_ETH_NODE} from "src/util/Constants.sol";
import {IAddrResolver} from "ens-contracts/resolvers/profiles/IAddrResolver.sol";
import {ITextResolver} from "ens-contracts/resolvers/profiles/ITextResolver.sol";
import {NameEncoder} from "ens-contracts/utils/NameEncoder.sol";
import {MockPublicResolver} from "test/mocks/MockPublicResolver.sol";

contract ResolveWithProof is L1ResolverTestBase {
    function test_returnsResultsWithValidSignature(string memory name) public {
        (bytes memory dnsName,) = NameEncoder.dnsEncodeName(name);
        vm.assume(keccak256(dnsName) != keccak256(BASE_ETH_NAME));

        (address expectedAddress, bytes memory callData, bytes memory result) = _setupProofCallback(name);

        uint64 expires = 1893456000; // 1/1/2030 00:00:00
        bytes32 digest = SignatureVerifier.makeSignatureHash(address(resolver), expires, callData, result);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPk, digest);
        bytes memory sig = abi.encodePacked(r, s, v);

        bytes memory gatewayResponse = abi.encode(result, expires, sig);
        bytes memory response = resolver.resolveWithProof(gatewayResponse, callData);
        (address returnedAddress) = abi.decode(response, (address));
        assertEq(returnedAddress, expectedAddress);
    }

    function test_revertsWhenTheSignatureIsExpired(string memory name) public {
        (bytes memory dnsName,) = NameEncoder.dnsEncodeName(name);
        vm.assume(keccak256(dnsName) != keccak256(BASE_ETH_NAME));

        (, bytes memory callData, bytes memory result) = _setupProofCallback(name);

        uint64 expires = 0;
        bytes32 digest = SignatureVerifier.makeSignatureHash(address(resolver), expires, callData, result);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPk, digest);
        bytes memory sig = abi.encodePacked(r, s, v);

        bytes memory gatewayResponse = abi.encode(result, expires, sig);
        vm.expectRevert(SignatureVerifier.SignatureExpired.selector);
        resolver.resolveWithProof(gatewayResponse, callData);
    }

    function test_revertsWhenTheSignerIsInvalid(string memory name) public {
        (bytes memory dnsName,) = NameEncoder.dnsEncodeName(name);
        vm.assume(keccak256(dnsName) != keccak256(BASE_ETH_NAME));

        (, bytes memory callData, bytes memory result) = _setupProofCallback(name);

        uint64 expires = 1893456000; // 1/1/2030 00:00:00
        bytes32 digest = SignatureVerifier.makeSignatureHash(address(resolver), expires, callData, result);
        uint256 pk = 1;
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(pk, digest);
        bytes memory sig = abi.encodePacked(r, s, v);

        bytes memory gatewayResponse = abi.encode(result, expires, sig);
        vm.expectRevert(L1Resolver.InvalidSigner.selector);
        resolver.resolveWithProof(gatewayResponse, callData);
    }

    function _setupProofCallback(string memory name)
        internal
        returns (address expectedAddress, bytes memory callData, bytes memory result)
    {
        (bytes memory dnsName, bytes32 node) = NameEncoder.dnsEncodeName(name);
        expectedAddress = makeAddr(name);
        bytes memory data = abi.encodeWithSelector(IAddrResolver.addr.selector, node);
        callData = abi.encodeWithSelector(resolver.resolve.selector, dnsName, data);
        result = abi.encode(expectedAddress);
    }
}
