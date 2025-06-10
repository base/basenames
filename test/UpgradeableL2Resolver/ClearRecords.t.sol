// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {UpgradeableL2ResolverBase} from "./UpgradeableL2ResolverBase.t.sol";
import {ResolverBase} from "src/L2/resolver/ResolverBase.sol";

import {IVersionableResolver} from "ens-contracts/resolvers/profiles/IVersionableResolver.sol";

contract ClearRecords is UpgradeableL2ResolverBase {
    function test_reverts_forUnauthorizedUser() public {
        vm.expectRevert(abi.encodeWithSelector(ResolverBase.NotAuthorized.selector, node, notUser));
        vm.prank(notUser);
        resolver.clearRecords(node);
    }

    function test_clearRecords() public {
        uint64 currentRecordVersion = resolver.recordVersions(node);
        vm.prank(user);
        vm.expectEmit(address(resolver));
        emit IVersionableResolver.VersionChanged(node, currentRecordVersion + 1);
        resolver.clearRecords(node);
    }
}
