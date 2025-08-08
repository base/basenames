// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {UpgradeableL2ResolverBase} from "./UpgradeableL2ResolverBase.t.sol";
import {L2Resolver} from "src/L2/L2Resolver.sol";

contract SetApprovalForAll is UpgradeableL2ResolverBase {
    function test_revertsIfCalledForSelf() public {
        vm.expectRevert(L2Resolver.CantSetSelfAsOperator.selector);
        vm.prank(user);
        resolver.setApprovalForAll(user, true);
    }

    function test_allowsSenderToSetApproval(address operator, bool approve) public {
        vm.assume(operator != user);
        vm.expectEmit(address(resolver));
        emit L2Resolver.ApprovalForAll(user, operator, approve);
        vm.prank(user);
        resolver.setApprovalForAll(operator, approve);
        assertEq(resolver.isApprovedForAll(user, operator), approve);
    }
}
