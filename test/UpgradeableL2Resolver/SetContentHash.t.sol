// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {UpgradeableL2ResolverBase} from "./UpgradeableL2ResolverBase.t.sol";
import {ResolverBase} from "src/L2/resolver/ResolverBase.sol";
import {ContentHashResolver} from "src/L2/resolver/ContentHashResolver.sol";

contract SetContenthash is UpgradeableL2ResolverBase {
    bytes IPFS_Data = hex"e3010170122029f2d17be6139079dc48696d1f582a8530eb9805b561eda517e22a892c7e3f1f";

    function test_reverts_forUnauthorizedUser() public {
        vm.expectRevert(abi.encodeWithSelector(ResolverBase.NotAuthorized.selector, node, notUser));
        vm.prank(notUser);
        resolver.setContenthash(node, IPFS_Data);
    }

    function test_setsAContenthash() public {
        vm.prank(user);
        resolver.setContenthash(node, IPFS_Data);
        assertEq(keccak256(resolver.contenthash(node)), keccak256(IPFS_Data));
    }

    function test_canClearRecord() public {
        vm.startPrank(user);

        resolver.setContenthash(node, IPFS_Data);
        assertEq(resolver.contenthash(node), IPFS_Data);

        resolver.clearRecords(node);
        assertEq(resolver.contenthash(node), "");

        vm.stopPrank();
    }
}
