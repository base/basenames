//SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {IntegrationTestBase} from "./IntegrationTestBase.t.sol";
import {MigrationController} from "src/L2/MigrationController.sol";

contract ForwardResolutionMigration is IntegrationTestBase {
    MigrationController migrationController;
    uint256 BASE_COINTYPE = 0x80002105;
    bytes32 aliceNode;

    function setUp() public override {
        super.setUp();
        migrationController = new MigrationController(registry, BASE_COINTYPE, address(defaultL2Resolver), owner);

        aliceNode = _registerAlice();
    }

    function test_allowsTheOwnerToMigrateAUser() public {
        vm.startPrank(owner);
        defaultL2Resolver.setRegistrarController(address(migrationController));

        bytes32[] memory nodes = new bytes32[](1);
        nodes[0] = aliceNode;

        migrationController.setBaseForwardAddr(nodes);

        bytes memory aliceAddr = defaultL2Resolver.addr(aliceNode, BASE_COINTYPE);

        assertEq(_bytesToAddress(aliceAddr), alice);
    }

    function _bytesToAddress(bytes memory b) internal pure returns (address payable a) {
        require(b.length == 20);
        assembly {
            a := div(mload(add(b, 32)), exp(256, 12))
        }
    }
}
