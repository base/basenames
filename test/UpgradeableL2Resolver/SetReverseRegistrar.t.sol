// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {UpgradeableL2ResolverBase} from "./UpgradeableL2ResolverBase.t.sol";
import {UpgradeableL2Resolver} from "src/L2/UpgradeableL2Resolver.sol";
import {OwnableUpgradeable} from "lib/openzeppelin-contracts-upgradeable/contracts/access/OwnableUpgradeable.sol";

contract SetReverseRegistrar is UpgradeableL2ResolverBase {
    function test_reverts_ifCalledByNonOwner(address caller, address newReverse) public notProxyAdmin(caller) {
        vm.assume(caller != owner);
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, caller));
        vm.prank(caller);
        resolver.setReverseRegistrar(newReverse);
    }

    function test_reverts_ifSettingNewReverseRegistrarToZeroAddress() public {
        vm.expectRevert(UpgradeableL2Resolver.NoZeroAddress.selector);
        vm.prank(owner);
        resolver.setReverseRegistrar(address(0));
    }

    function test_setsTheReverseRegistrarAccordingly(address newReverse) public {
        vm.assume(newReverse != address(0));
        vm.expectEmit();
        emit UpgradeableL2Resolver.ReverseRegistrarUpdated(newReverse);
        vm.prank(owner);
        resolver.setReverseRegistrar(newReverse);
        assertEq(resolver.reverseRegistrar(), newReverse);
    }
}
