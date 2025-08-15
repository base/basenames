//SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Test, console} from "forge-std/Test.sol";
import {L1ResolverTestBase} from "./L1ResolverBase.t.sol";

import {L1Resolver} from "src/L1/L1Resolver.sol";
import {Ownable} from "solady/auth/Ownable.sol";

contract AdminMethods is L1ResolverTestBase {
    function test_setUrl(string memory newUrl) public {
        vm.prank(makeAddr("0x2"));
        vm.expectRevert(abi.encodeWithSelector(Ownable.Unauthorized.selector));
        resolver.setUrl(newUrl);

        vm.prank(owner);
        vm.expectEmit();
        emit L1Resolver.UrlChanged(newUrl);
        resolver.setUrl(newUrl);
    }

    function test_addSigners(address[] calldata _signers) public {
        vm.assume(_signers.length < 10);
        for (uint256 i; i < _signers.length; i++) {
            vm.assume(_signers[i] != address(0));
        }

        vm.prank(makeAddr("0x2"));
        vm.expectRevert(abi.encodeWithSelector(Ownable.Unauthorized.selector));
        resolver.addSigners(_signers);

        vm.prank(owner);
        vm.expectEmit();
        emit L1Resolver.AddedSigners(_signers);
        resolver.addSigners(_signers);
        for (uint256 i; i < _signers.length; i++) {
            assertTrue(resolver.signers(_signers[i]));
        }
    }

    function test_removeSigner() public {
        vm.prank(makeAddr("0x2"));
        vm.expectRevert(abi.encodeWithSelector(Ownable.Unauthorized.selector));
        resolver.removeSigner(signer);

        assertTrue(resolver.signers(signer));
        vm.prank(owner);
        vm.expectEmit();
        emit L1Resolver.RemovedSigner(signer);
        resolver.removeSigner(signer);
        assertFalse(resolver.signers(signer));
    }

    function test_setRootResolver(address newResolver) public {
        vm.prank(makeAddr("0x2"));
        vm.expectRevert(abi.encodeWithSelector(Ownable.Unauthorized.selector));
        resolver.setRootResolver(newResolver);

        vm.prank(owner);
        vm.expectEmit();
        emit L1Resolver.RootResolverChanged(newResolver);
        resolver.setRootResolver(newResolver);
    }
}
