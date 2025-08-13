//SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Test, console} from "forge-std/Test.sol";
import {L1ResolverTestBase} from "./L1ResolverBase.t.sol";

import {L1Resolver} from "src/L1/L1Resolver.sol";
import {BASE_ETH_NODE} from "src/util/Constants.sol";
import {IAddrResolver} from "ens-contracts/resolvers/profiles/IAddrResolver.sol";
import {ITextResolver} from "ens-contracts/resolvers/profiles/ITextResolver.sol";
import {MockPublicResolver} from "test/mocks/MockPublicResolver.sol";

contract Fallback is L1ResolverTestBase {
    function test_forwardsAddrCall_whenResolvingRootName() public {
        bytes memory data = abi.encodeWithSelector(IAddrResolver.addr.selector, BASE_ETH_NODE);
        (, bytes memory response) = address(resolver).call{value: 0}(data);
        (address resolvedAddress) = abi.decode(response, (address));
        assert(resolvedAddress == MockPublicResolver(rootResolver).ADDRESS());
    }

    function test_forwardsTextCall_whenResolvingRootName() public {
        bytes memory data = abi.encodeWithSelector(ITextResolver.text.selector, BASE_ETH_NODE, "test");
        (, bytes memory response) = address(resolver).call{value: 0}(data);
        (string memory resolvedText) = abi.decode(response, (string));
        assert(keccak256(bytes(resolvedText)) == keccak256(bytes(MockPublicResolver(rootResolver).TEST_TEXT())));
    }
}
