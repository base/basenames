// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {UpgradeableL2ResolverBase} from "./UpgradeableL2ResolverBase.t.sol";
import {UpgradeableL2Resolver} from "src/L2/UpgradeableL2Resolver.sol";

contract Approve is UpgradeableL2ResolverBase {
    function test_revertsIfCalledForSelf() public {
        vm.expectRevert(UpgradeableL2Resolver.CantSetSelfAsDelegate.selector);
        vm.prank(user);
        resolver.approve(node, user, true);
    }

    function test_allowsSenderToSetDelegate(address operator) public {
        vm.assume(operator != user);
        vm.expectEmit(address(resolver));
        emit UpgradeableL2Resolver.Approved(user, node, operator, true);
        vm.prank(user);
        resolver.approve(node, operator, true);
        assertTrue(resolver.isApprovedFor(user, node, operator));
    }
}
