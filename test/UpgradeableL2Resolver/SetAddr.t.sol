// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {UpgradeableL2ResolverBase} from "./UpgradeableL2ResolverBase.t.sol";
import {ResolverBase} from "src/L2/resolver/ResolverBase.sol";
import {AddrResolver} from "src/L2/resolver/AddrResolver.sol";

contract SetAddr is UpgradeableL2ResolverBase {
    uint256 BTC_COINTYPE = 0;
    uint256 ETH_COINTYPE = 60;
    uint256 BASE_COINTYPE = 2147492101;
    uint256 COIN_TYPE_DEFAULT = 1 << 31; // 0x8000_0000

    function test_reverts_forUnauthorizedUser() public {
        vm.expectRevert(abi.encodeWithSelector(ResolverBase.NotAuthorized.selector, node, notUser));
        vm.prank(notUser);
        resolver.setAddr(node, notUser);
    }

    function test_reverts_for_invalidAddress() public {
        vm.prank(user);
        vm.expectRevert();
        resolver.setAddr(node, 60, "badadd");
    }

    function test_reverts_whenInvalidEVMAddress() public {
        bytes memory badAddr = bytes("1234");
        vm.expectRevert(abi.encodeWithSelector(AddrResolver.InvalidEVMAddress.selector, badAddr));
        vm.prank(user);
        resolver.setAddr(node, BASE_COINTYPE, badAddr);
    }

    function test_setsAnETHAddress_byDefault(address a) public {
        vm.prank(user);
        resolver.setAddr(node, a);
        assertEq(resolver.addr(node), a);
        assertEq(bytesToAddress(resolver.addr(node, ETH_COINTYPE)), a);
    }

    function test_setsAnETHAddress(address a) public {
        vm.prank(user);
        resolver.setAddr(node, ETH_COINTYPE, addressToBytes(a));
        assertEq(resolver.addr(node), a);
        assertEq(bytesToAddress(resolver.addr(node, ETH_COINTYPE)), a);
    }

    function test_letsAUserSetZeroAddress_forEthCointype() public {
        vm.prank(user);
        resolver.setAddr(node, address(0));
        assertEq(resolver.addr(node), address(0));
    }

    function test_letsAUserSetZeroAddress_forEthCointypeWithExplicitCointype() public {
        vm.prank(user);
        resolver.setAddr(node, ETH_COINTYPE, bytes(""));
        assertEq(resolver.addr(node), address(0));
    }

    function test_setsABaseAddress(address a) public {
        vm.prank(user);
        resolver.setAddr(node, BASE_COINTYPE, addressToBytes(a));
        assertEq(bytesToAddress(resolver.addr(node, BASE_COINTYPE)), a);
    }

    function test_setsADefaultAddress(address a) public {
        vm.prank(user);
        resolver.setAddr(node, COIN_TYPE_DEFAULT, addressToBytes(a));
        assertEq(bytesToAddress(resolver.addr(node, COIN_TYPE_DEFAULT)), a);
    }

    function test_fetchesDefaultForBaseCointype(address a) public {
        vm.prank(user);
        resolver.setAddr(node, COIN_TYPE_DEFAULT, addressToBytes(a));
        assertEq(bytesToAddress(resolver.addr(node, BASE_COINTYPE)), a);
    }

    function test_setsABtcAddress() public {
        bytes memory satoshi = hex"76a91462e907b15cbf27d5425399ebf6f0fb50ebb88f1888ac";
        vm.prank(user);
        resolver.setAddr(node, BTC_COINTYPE, satoshi);
        assertEq(keccak256(resolver.addr(node, BTC_COINTYPE)), keccak256(satoshi));
    }

    function test_canClearRecord(address a) public {
        vm.startPrank(user);

        resolver.setAddr(node, a);
        assertEq(resolver.addr(node), a);

        resolver.clearRecords(node);
        assertEq(resolver.addr(node), address(0));

        vm.stopPrank();
    }

    /// @notice Helper to convert bytes into an EVM address object.
    function bytesToAddress(bytes memory b) internal pure returns (address payable a) {
        require(b.length == 20);
        assembly {
            a := div(mload(add(b, 32)), exp(256, 12))
        }
    }

    /// @notice Helper to convert an EVM address to a bytes object.
    function addressToBytes(address a) internal pure returns (bytes memory b) {
        b = new bytes(20);
        assembly {
            mstore(add(b, 32), mul(a, exp(256, 12)))
        }
    }
}
