// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {UpgradeableL2ResolverBase} from "./UpgradeableL2ResolverBase.t.sol";
import {ResolverBase} from "src/L2/resolver/ResolverBase.sol";
import {PubkeyResolver} from "src/L2/resolver/PubkeyResolver.sol";

contract SetPubkey is UpgradeableL2ResolverBase {
    bytes32 x = 0x65a2fa44daad46eab0278703edb6c4dcf5e30b8a9aec09fdc71a56f52aa392e4;
    bytes32 y = 0x4a7a9e4604aa36898209997288e902ac544a555e4b5e0a9efef2b59233f3f437;

    function test_reverts_forUnauthorizedUser() public {
        vm.expectRevert(abi.encodeWithSelector(ResolverBase.NotAuthorized.selector, node, notUser));
        vm.prank(notUser);
        resolver.setPubkey(node, x, y);
    }

    function test_setsThePubkey() public {
        vm.prank(user);
        resolver.setPubkey(node, x, y);
        (bytes32 retX, bytes32 retY) = resolver.pubkey(node);
        assertEq(retX, x);
        assertEq(retY, y);
    }

    function test_canClearRecord() public {
        vm.startPrank(user);

        resolver.setPubkey(node, x, y);
        (bytes32 retX, bytes32 retY) = resolver.pubkey(node);
        assertEq(retX, x);
        assertEq(retY, y);

        resolver.clearRecords(node);
        (retX, retY) = resolver.pubkey(node);
        assertEq(retX, 0);
        assertEq(retY, 0);

        vm.stopPrank();
    }
}
