// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {UpgradeableL2ResolverBase} from "./UpgradeableL2ResolverBase.t.sol";
import {UpgradeableL2Resolver} from "src/L2/UpgradeableL2Resolver.sol";
import {Ownable} from "solady/auth/Ownable.sol";

contract SetRegistrarController is UpgradeableL2ResolverBase {
    function test_reverts_ifCalledByNonOwner(address caller, address newController) public notProxyAdmin(caller) {
        vm.assume(caller != owner);
        vm.expectRevert(Ownable.Unauthorized.selector);
        vm.prank(caller);
        resolver.setRegistrarController(newController);
    }

    function test_setsTheRegistrarControllerAccordingly(address newController) public {
        vm.expectEmit();
        emit UpgradeableL2Resolver.RegistrarControllerUpdated(newController);
        vm.prank(owner);
        resolver.setRegistrarController(newController);
        assertEq(resolver.registrarController(), newController);
    }
}
