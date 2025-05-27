//SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {ReverseRegistrarV2Base} from "./ReverseRegistrarV2Base.t.sol";
import {ReverseRegistrarV2} from "src/L2/ReverseRegistrarV2.sol";
import {Sha3} from "src/lib/Sha3.sol";
import {BASE_ETH_NODE} from "src/util/Constants.sol";
import {MockAddrResolver} from "test/mocks/MockAddrResolver.sol";
import {Ownable} from "solady/auth/Ownable.sol";

import {console} from "forge-std/console.sol";

contract SetBaseForwardAddr is ReverseRegistrarV2Base {
    MockAddrResolver addrResolver;
    bytes32 fwdNode;

    function setUp() public override {
        super.setUp();
        addrResolver = new MockAddrResolver();

        _setupRegistry();

        vm.prank(owner);
        reverse.setDefaultResolver(address(addrResolver));
    }

    function test_reverts_whenCalledByNonOwner(address caller) public {
        vm.assume(caller != owner);
        vm.expectRevert(Ownable.Unauthorized.selector);
        vm.prank(caller);
        reverse.setDefaultResolver(makeAddr("fake"));
    }

    function test_continuesWhen_resolverIsNotDefaultResolver() public {
        // Set resolver to user's own address
        vm.prank(user);
        registry.setResolver(fwdNode, user);

        vm.prank(owner);
        reverse.setBaseForwardAddr(_getNodes());

        bytes memory retAddr = addrResolver.addr(fwdNode, BASE_COINTYPE);
        assertEq(keccak256(retAddr), keccak256(""));
    }

    function test_continuesWhen_resolvedAddrIsInvalid() public {
        // Set resolver to addr resolver address
        vm.prank(user);
        registry.setResolver(fwdNode, address(addrResolver));

        vm.prank(owner);
        reverse.setBaseForwardAddr(_getNodes());

        bytes memory retAddr = addrResolver.addr(fwdNode, BASE_COINTYPE);
        assertEq(keccak256(retAddr), keccak256(""));
    }

    function test_continuesWhen_thereIsAlreadyAnAddressStored() public {
        vm.startPrank(user);
        // Set resolver to addr resolver address
        registry.setResolver(fwdNode, address(addrResolver));
        // Set the ensip-11 network address to user's address
        addrResolver.setAddr(fwdNode, BASE_COINTYPE, _addressToBytes(user));
        // Set the legacy addr vield to some new address
        addrResolver.setAddr(fwdNode, makeAddr("user2"));
        vm.stopPrank();

        vm.prank(owner);
        reverse.setBaseForwardAddr(_getNodes());

        address retAddr = _bytesToAddress(addrResolver.addr(fwdNode, BASE_COINTYPE));
        // Assert that the returned address for the network is the user's address
        assertEq(retAddr, user);
    }

    function test_setsTheAddressAsExpected() public {
        vm.startPrank(user);
        // Set resolver to addr resolver address
        registry.setResolver(fwdNode, address(addrResolver));
        // Set the legacy addr field to user's address
        addrResolver.setAddr(fwdNode, user);
        vm.stopPrank();

        vm.prank(owner);
        reverse.setBaseForwardAddr(_getNodes());

        address retAddr = _bytesToAddress(addrResolver.addr(fwdNode, BASE_COINTYPE));
        // Assert that the returned address for the network is the user's address
        assertEq(retAddr, user);
    }

    function _setupRegistry() internal {
        bytes32 nameLabel = keccak256("name");
        vm.prank(owner);
        registry.setSubnodeOwner(BASE_ETH_NODE, nameLabel, user);
        fwdNode = keccak256(abi.encodePacked(BASE_ETH_NODE, nameLabel));
    }

    function _getNodes() internal view returns (bytes32[] memory nodes) {
        nodes = new bytes32[](1);
        nodes[0] = fwdNode;
    }

    /// @notice Helper for converting an address stored as bytes into an address type.
    ///
    /// @dev Copied from ENS `AddrResolver`:
    ///     https://github.com/ensdomains/ens-contracts/blob/staging/contracts/resolvers/profiles/AddrResolver.sol
    ///
    /// @param b Address bytes.
    function _bytesToAddress(bytes memory b) internal pure returns (address payable a) {
        require(b.length == 20);
        assembly {
            a := div(mload(add(b, 32)), exp(256, 12))
        }
    }

    /// @notice Helper for converting an address into a bytes object.
    ///
    /// @dev Copied from ENS `AddrResolver`:
    ///     https://github.com/ensdomains/ens-contracts/blob/staging/contracts/resolvers/profiles/AddrResolver.sol
    ///
    /// @param a Address.
    function _addressToBytes(address a) internal pure returns (bytes memory b) {
        b = new bytes(20);
        assembly {
            mstore(add(b, 32), mul(a, exp(256, 12)))
        }
    }
}
