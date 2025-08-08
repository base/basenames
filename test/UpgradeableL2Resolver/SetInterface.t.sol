// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {ERC165} from "lib/openzeppelin-contracts/contracts/utils/introspection/ERC165.sol";
import {UpgradeableL2ResolverBase} from "./UpgradeableL2ResolverBase.t.sol";
import {ResolverBase} from "src/L2/resolver/ResolverBase.sol";
import {InterfaceResolver} from "src/L2/resolver/InterfaceResolver.sol";

contract SetInterface is UpgradeableL2ResolverBase {
    Counter counter;

    function setUp() public override {
        super.setUp();
        counter = new Counter();
    }

    function test_reverts_forUnauthorizedUser() public {
        vm.expectRevert(abi.encodeWithSelector(ResolverBase.NotAuthorized.selector, node, notUser));
        vm.prank(notUser);
        resolver.setInterface(node, type(ICounter).interfaceId, address(counter));
    }

    function test_setsTheInterface_whenTheAddressIsSpecifiedExplicitly() public {
        vm.prank(user);
        resolver.setInterface(node, type(ICounter).interfaceId, address(counter));
        assertEq(resolver.interfaceImplementer(node, type(ICounter).interfaceId), address(counter));
    }

    function test_returnsTheInterface_whenTheAddressIsSetToTheAddrProfile() public {
        vm.prank(user);
        resolver.setAddr(node, address(counter));
        assertEq(resolver.interfaceImplementer(node, type(ICounter).interfaceId), address(counter));
    }

    function test_returnsZeroAddress_whenNotSet() public view {
        assertEq(resolver.interfaceImplementer(node, type(ICounter).interfaceId), address(0));
    }

    function test_returnsZeroAddress_whenAddressIsNotContract(address notContract) public {
        vm.assume(notContract.code.length == 0);
        assumeNotPrecompile(notContract);

        vm.prank(user);
        resolver.setAddr(node, address(notContract));
        assertEq(resolver.addr(node), notContract);

        assertEq(resolver.interfaceImplementer(node, type(ICounter).interfaceId), address(0));
    }

    function test_returnsZeroAddr_whenNotImplemented() public {
        vm.prank(user);
        resolver.setAddr(node, address(counter));
        assertEq(resolver.interfaceImplementer(node, type(IGreeter).interfaceId), address(0));
    }

    function test_canClearRecord() public {
        vm.startPrank(user);

        resolver.setInterface(node, type(ICounter).interfaceId, address(counter));
        assertEq(resolver.interfaceImplementer(node, type(ICounter).interfaceId), address(counter));

        resolver.clearRecords(node);
        assertEq(resolver.interfaceImplementer(node, type(ICounter).interfaceId), address(0));

        vm.stopPrank();
    }
}

interface ICounter {
    function set(uint256 x) external;
}

interface IGreeter {
    function greet() external returns (string memory);
}

contract Counter is ICounter, ERC165 {
    uint256 public x;

    function set(uint256 x_) external {
        x = x_;
    }

    /// @notice ERC-165 compliance.
    function supportsInterface(bytes4 interfaceID) public view virtual override returns (bool) {
        return interfaceID == type(ICounter).interfaceId || super.supportsInterface(interfaceID);
    }
}
