//SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Test, console} from "forge-std/Test.sol";
import {L1ResolverTestBase} from "./L1ResolverBase.t.sol";

import {L1Resolver} from "src/L1/L1Resolver.sol";
import {Ownable} from "solady/auth/Ownable.sol";
import {SignatureVerifier} from "src/lib/SignatureVerifier.sol";
import {BASE_ETH_NAME, BASE_ETH_NODE} from "src/util/Constants.sol";
import {IAddrResolver} from "ens-contracts/resolvers/profiles/IAddrResolver.sol";
import {ITextResolver} from "ens-contracts/resolvers/profiles/ITextResolver.sol";
import {NameEncoder} from "ens-contracts/utils/NameEncoder.sol";
import {MockPublicResolver} from "test/mocks/MockPublicResolver.sol";

contract Resolve is L1ResolverTestBase {
    function test_revertsWithOffchainLookup_whenResolvingName(string memory name) public {
        (bytes memory dnsName, bytes32 node) = NameEncoder.dnsEncodeName(name);
        vm.assume(keccak256(dnsName) != keccak256(BASE_ETH_NAME));

        bytes memory data = abi.encodeWithSelector(IAddrResolver.addr.selector, node);
        bytes memory callData = abi.encodeWithSelector(resolver.resolve.selector, dnsName, data);
        string[] memory urls = new string[](1);
        urls[0] = resolver.url();
        vm.expectRevert(
            abi.encodeWithSelector(
                L1Resolver.OffchainLookup.selector,
                address(resolver),
                urls,
                callData,
                L1Resolver.resolveWithProof.selector,
                callData
            )
        );
        resolver.resolve(dnsName, data);
    }

    function test_resolvesAddr_whenCallingforRootName() public view {
        bytes memory data = abi.encodeWithSelector(IAddrResolver.addr.selector, BASE_ETH_NODE);
        bytes memory response = resolver.resolve(BASE_ETH_NAME, data);
        (address resolvedAddress) = abi.decode(response, (address));
        assert(resolvedAddress == MockPublicResolver(rootResolver).ADDRESS());
    }

    function test_resolvesText_whenCallingforRootName() public view {
        bytes memory data = abi.encodeWithSelector(ITextResolver.text.selector, BASE_ETH_NODE, "test");
        bytes memory response = resolver.resolve(BASE_ETH_NAME, data);
        (string memory resolvedText) = abi.decode(response, (string));
        assert(keccak256(bytes(resolvedText)) == keccak256(bytes(MockPublicResolver(rootResolver).TEST_TEXT())));
    }
}
