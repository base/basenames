//SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {MigrationControllerBase} from "./MigrationControllerBase.t.sol";
import {Ownable} from "openzeppelin-contracts/contracts/access/Ownable.sol";

contract SetBaseForwardAddr is MigrationControllerBase {
    function test_revertsWhen_calledByNonOwner(address caller) public {
        vm.assume(caller != owner);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, caller));
        vm.prank(caller);
        migrationController.setBaseForwardAddr(new bytes32[](1));
    }

    function test_continuesWhenTheResolverIsNotTheDefaultResolver() public {
        _setupAliceNode();
        vm.prank(alice);
        registry.setResolver(aliceNode, makeAddr("newResolver"));

        vm.prank(owner);
        migrationController.setBaseForwardAddr(_getNodesArray());

        assertEq(resolver.addr(aliceNode, BASE_COINTYPE), "");
    }

    function test_continuesWhenTheAddrRecordIsNotSet() public {
        _setupAliceNode();

        vm.prank(owner);
        migrationController.setBaseForwardAddr(_getNodesArray());

        assertEq(resolver.addr(aliceNode, BASE_COINTYPE), "");
    }

    function test_continuesWhenAnEnsip11AddressIsAlreadySet() public {
        _setupAliceNode();
        _createBaseAddrResolverRecord();

        vm.prank(owner);
        migrationController.setBaseForwardAddr(_getNodesArray());

        assertEq(bytesToAddress(resolver.addr(aliceNode, BASE_COINTYPE)), alice);
    }

    function test_setsTheEnsip11AddressCorrectly() public {
        _setupAliceNode();
        _createAddrResolverRecord();

        vm.prank(owner);
        migrationController.setBaseForwardAddr(_getNodesArray());

        assertEq(bytesToAddress(resolver.addr(aliceNode, BASE_COINTYPE)), alice);
    }
}
