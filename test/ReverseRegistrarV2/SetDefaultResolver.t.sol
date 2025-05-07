//SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {NameResolver} from "ens-contracts/resolvers/profiles/NameResolver.sol";
import {Ownable} from "solady/auth/Ownable.sol";
import {ReverseRegistrarV2Base} from "./ReverseRegistrarV2Base.t.sol";
import {ReverseRegistrarV2} from "src/L2/ReverseRegistrarV2.sol";

contract SetDefaultResolver is ReverseRegistrarV2Base {
    function test_reverts_whenCalledByNonOwner(address caller) public {
        vm.assume(caller != owner);
        vm.expectRevert(Ownable.Unauthorized.selector);
        vm.prank(caller);
        reverse.setDefaultResolver(makeAddr("fake"));
    }

    function test_reverts_whenPassedZeroAddress() public {
        vm.expectRevert(ReverseRegistrarV2.NoZeroAddress.selector);
        vm.prank(owner);
        reverse.setDefaultResolver(address(0));
    }

    function test_setsTheDefaultResolver() public {
        vm.expectEmit(address(reverse));
        emit ReverseRegistrarV2.DefaultResolverChanged(address(resolver));
        vm.prank(owner);
        reverse.setDefaultResolver(address(resolver));
        assertTrue(reverse.defaultResolver() == address(resolver));
    }
}
