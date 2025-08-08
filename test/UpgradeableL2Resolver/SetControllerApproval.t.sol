// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {UpgradeableL2ResolverBase} from "./UpgradeableL2ResolverBase.t.sol";
import {UpgradeableL2Resolver} from "src/L2/UpgradeableL2Resolver.sol";
import {OwnableUpgradeable} from "lib/openzeppelin-contracts-upgradeable/contracts/access/OwnableUpgradeable.sol";

contract SetControllerApproval is UpgradeableL2ResolverBase {
    function test_reverts_ifCalledByNonOwner(address caller, address newController) public notProxyAdmin(caller) {
        vm.assume(caller != owner);
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, caller));
        vm.prank(caller);
        resolver.setControllerApproval(newController, true);
    }

    function test_reverts_ifSettingNewControllerToZeroAddress() public {
        vm.expectRevert(UpgradeableL2Resolver.NoZeroAddress.selector);
        vm.prank(owner);
        resolver.setControllerApproval(address(0), true);
    }

    function test_setsTheRegistrarControllerAccordingly(address newController) public {
        vm.assume(newController != address(0));
        vm.expectEmit();
        emit UpgradeableL2Resolver.ControllerApprovalChanged(newController, true);
        vm.prank(owner);
        resolver.setControllerApproval(newController, true);
        assertTrue(resolver.getControllerApproval(newController));
    }
}
