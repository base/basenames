// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {UpgradeableL2ResolverBase} from "./UpgradeableL2ResolverBase.t.sol";
import {UpgradeableL2Resolver} from "src/L2/UpgradeableL2Resolver.sol";
import {Ownable} from "solady/auth/Ownable.sol";

contract SetReverseRegistrar is UpgradeableL2ResolverBase {
    function test_reverts_ifCalledByNonOwner(address caller, address newReverse) public notProxyAdmin(caller) {
        vm.assume(caller != owner);
        vm.expectRevert(Ownable.Unauthorized.selector);
        vm.prank(caller);
        resolver.setReverseRegistrar(newReverse);
    }

    function test_setsTheReverseRegistrarAccordingly(address newReverse) public {
        vm.expectEmit();
        emit UpgradeableL2Resolver.ReverseRegistrarUpdated(newReverse);
        vm.prank(owner);
        resolver.setReverseRegistrar(newReverse);
        assertEq(resolver.reverseRegistrar(), newReverse);
    }
}
