//SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {ReverseRegistrarV2Base} from "./ReverseRegistrarV2Base.t.sol";
import {ReverseRegistrar} from "src/L2/ReverseRegistrar.sol";
import {Ownable} from "solady/auth/Ownable.sol";

contract SetControllerApproval is ReverseRegistrarV2Base {
    function test_reverts_ifCalledByNonOwner(address caller) public {
        vm.assume(caller != owner && caller != address(0));
        vm.expectRevert(Ownable.Unauthorized.selector);
        reverse.setControllerApproval(caller, true);
    }

    function test_allowsTheOwner_toUpdateControllerApproval(address newController) public {
        vm.assume(newController != address(0));

        vm.expectEmit(address(reverse));
        emit ReverseRegistrar.ControllerApprovalChanged(newController, true);
        vm.prank(owner);
        reverse.setControllerApproval(newController, true);
        assertTrue(reverse.controllers(newController));

        vm.expectEmit(address(reverse));
        emit ReverseRegistrar.ControllerApprovalChanged(newController, false);
        vm.prank(owner);
        reverse.setControllerApproval(newController, false);
        assertFalse(reverse.controllers(newController));
    }
}
