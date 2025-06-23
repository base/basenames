// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {UpgradeableL2ResolverBase} from "./UpgradeableL2ResolverBase.t.sol";

contract SetRegistrarController is UpgradeableL2ResolverBase {
    function test_UpgradeableResolverStorage_matchesExpectedSlot() external pure {
        /// @notice EIP-7201 storage location.
        // keccak256(abi.encode(uint256(keccak256("resolver.storage")) - 1)) & ~bytes32(uint256(0xff));
        // bytes32 private constant RESOLVER_STORAGE_LOCATION = 0xa75da70a48b778f6d7794a48ad897d5e41dff6abea13a6164e9a58efe57a7200;
        bytes32 expectedSlot =
            keccak256(abi.encode(uint256(keccak256("resolver.storage")) - 1)) & ~bytes32(uint256(0xff));
        assertEq(expectedSlot, 0xa75da70a48b778f6d7794a48ad897d5e41dff6abea13a6164e9a58efe57a7200);
    }

    function test_ABIResolverStorage_matchesExpectedSlot() external pure {
        /// @notice EIP-7201 storage location.
        /// keccak256(abi.encode(uint256(keccak256("abi.resolver.storage")) - 1)) & ~bytes32(uint256(0xff));
        ///     bytes32 private constant ABI_RESOLVER_STORAGE = 0x76dc89e1c49d3cda8f11a131d381f3dbd0df1919a4e1a669330a2763d2821400;
        bytes32 expectedSlot =
            keccak256(abi.encode(uint256(keccak256("abi.resolver.storage")) - 1)) & ~bytes32(uint256(0xff));
        assertEq(expectedSlot, 0x76dc89e1c49d3cda8f11a131d381f3dbd0df1919a4e1a669330a2763d2821400);
    }

    function test_AddrResolverStorage_matchesExpectedSlot() external pure {
        /// @notice EIP-7201 storage location.
        // keccak256(abi.encode(uint256(keccak256("addr.resolver.storage")) - 1)) & ~bytes32(uint256(0xff));
        // bytes32 constant ADDR_RESOLVER_STORAGE = 0x1871a91a9a944f867849820431bb11c2d1625edae573523bceb5b38b8b8a7500;
        bytes32 expectedSlot =
            keccak256(abi.encode(uint256(keccak256("addr.resolver.storage")) - 1)) & ~bytes32(uint256(0xff));
        assertEq(expectedSlot, 0x1871a91a9a944f867849820431bb11c2d1625edae573523bceb5b38b8b8a7500);
    }

    function test_ContentHashResolverStorage_matchesExpectedSlot() external pure {
        /// @notice EIP-7201 storage location.
        // keccak256(abi.encode(uint256(keccak256("content.hash.resolver.storage")) - 1)) & ~bytes32(uint256(0xff));
        // bytes32 private constant CONTENT_HASH_RESOLVER_STORAGE = 0x3cead3a342b450f6c566db8bcc5888396a4bada4d226d84f6075be8f3245c100;
        bytes32 expectedSlot =
            keccak256(abi.encode(uint256(keccak256("content.hash.resolver.storage")) - 1)) & ~bytes32(uint256(0xff));
        assertEq(expectedSlot, 0x3cead3a342b450f6c566db8bcc5888396a4bada4d226d84f6075be8f3245c100);
    }

    function test_DNSResolverStorage_matchesExpectedSlot() external pure {
        /// @notice EIP-7201 storage location.
        // keccak256(abi.encode(uint256(keccak256("dns.resolver.storage")) - 1)) & ~bytes32(uint256(0xff));
        // bytes32 constant DNS_RESOLVER_STORAGE = 0x563d533dd0798ef1806840ff9a36667f1ac5e6f948db03cf7022b575f40ccd00;
        bytes32 expectedSlot =
            keccak256(abi.encode(uint256(keccak256("dns.resolver.storage")) - 1)) & ~bytes32(uint256(0xff));
        assertEq(expectedSlot, 0x563d533dd0798ef1806840ff9a36667f1ac5e6f948db03cf7022b575f40ccd00);
    }

    function test_InterfaceResolverStorage_matchesExpectedSlot() external pure {
        /// @notice EIP-7201 storage location.
        // keccak256(abi.encode(uint256(keccak256("interface.resolver.storage")) - 1)) & ~bytes32(uint256(0xff));
        // bytes32 constant INTERFACE_RESOLVER_STORAGE = 0x933ab330cd660334bb219a68b3bfaf86387ecd49e4e53a39e8310a5bd6910c00;
        bytes32 expectedSlot =
            keccak256(abi.encode(uint256(keccak256("interface.resolver.storage")) - 1)) & ~bytes32(uint256(0xff));
        assertEq(expectedSlot, 0x933ab330cd660334bb219a68b3bfaf86387ecd49e4e53a39e8310a5bd6910c00);
    }

    function test_NameResolverStorage_matchesExpectedSlot() external pure {
        /// @notice EIP-7201 storage location.
        // keccak256(abi.encode(uint256(keccak256("name.resolver.storage")) - 1)) & ~bytes32(uint256(0xff));
        // bytes32 constant NAME_RESOLVER_STORAGE = 0x23d7cb83bcf6186ccf590f4291f50469cd60b0ac3c413e76ea47a810986d8500;        bytes32 expectedSlot = keccak256(abi.encode(uint256(keccak256("resolver.storage")) - 1)) & ~bytes32(uint256(0xff));
        bytes32 expectedSlot =
            keccak256(abi.encode(uint256(keccak256("name.resolver.storage")) - 1)) & ~bytes32(uint256(0xff));
        assertEq(expectedSlot, 0x23d7cb83bcf6186ccf590f4291f50469cd60b0ac3c413e76ea47a810986d8500);
    }

    function test_PubkeyResolverStorage_matchesExpectedSlot() external pure {
        /// @notice EIP-7201 storage location.
        // keccak256(abi.encode(uint256(keccak256("pubkey.resolver.storage")) - 1)) & ~bytes32(uint256(0xff));
        // bytes32 constant PUBKEY_RESOLVER_STORAGE = 0x59a318c6a4da81295c2a32b42a02c3db057bb9422e2eb1f6e516ee3694b1ef00;
        bytes32 expectedSlot =
            keccak256(abi.encode(uint256(keccak256("pubkey.resolver.storage")) - 1)) & ~bytes32(uint256(0xff));
        assertEq(expectedSlot, 0x59a318c6a4da81295c2a32b42a02c3db057bb9422e2eb1f6e516ee3694b1ef00);
    }

    function test_TextResolverStorage_matchesExpectedSlot() external pure {
        /// @notice EIP-7201 storage location.
        // keccak256(abi.encode(uint256(keccak256("text.resolver.storage")) - 1)) & ~bytes32(uint256(0xff));
        // bytes32 constant TEXT_RESOLVER_STORAGE = 0x0795ed949e6fff5efdc94a1021939889222c7fb041954dcfee28c913f2af9200;
        bytes32 expectedSlot =
            keccak256(abi.encode(uint256(keccak256("text.resolver.storage")) - 1)) & ~bytes32(uint256(0xff));
        assertEq(expectedSlot, 0x0795ed949e6fff5efdc94a1021939889222c7fb041954dcfee28c913f2af9200);
    }
}
