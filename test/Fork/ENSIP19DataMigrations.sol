// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {BaseSepoliaForkBase} from "./BaseSepoliaForkBase.t.sol";
import {MigrationController} from "src/L2/MigrationController.sol";
import {ENS} from "ens-contracts/registry/ENS.sol";
import {AddrResolver} from "ens-contracts/resolvers/profiles/AddrResolver.sol";

interface IL2ReverseRegistrarWithMigration {
    function batchSetName(address[] calldata addresses) external;
}

interface IOwnable {
    function owner() external view returns (address);
}

interface IL2ResolverApprove {
    function approve(bytes32 node, address delegate, bool approved) external;
}

contract ENSIP19DataMigrations is BaseSepoliaForkBase {
    address internal constant MIGRATION_CONTROLLER = 0xE8A87034a06425476F2bD6fD14EA038332Cc5e10;

    function test_migration_controller_setBaseForwardAddr() public {
        string memory name = "migratefwd";
        bytes32 root = legacyController.rootNode();
        bytes32 node = keccak256(abi.encodePacked(root, _labelFor(name)));

        // Register a name with legacy resolver
        RegistrarControllerLike legacy = RegistrarControllerLike(LEGACY_GA_CONTROLLER);
        uint256 price = legacy.registerPrice(name, 365 days);
        vm.deal(user, price);
        vm.prank(user);
        legacy.register{value: price}(
            RegistrarControllerLike.RegisterRequest({
                name: name,
                owner: user,
                duration: 365 days,
                resolver: LEGACY_L2_RESOLVER,
                data: new bytes[](0),
                reverseRecord: false
            })
        );

        // Set a default EVM addr on the resolver so there is something to migrate
        vm.prank(user);
        AddrResolver(LEGACY_L2_RESOLVER).setAddr(node, user);

        // Authorize the MigrationController to write records for this node
        vm.prank(user);
        IL2ResolverApprove(LEGACY_L2_RESOLVER).approve(node, MIGRATION_CONTROLLER, true);

        uint256 coinType = MigrationController(MIGRATION_CONTROLLER).coinType();

        // Pre: ENSIP-11 (coinType) record should be empty
        bytes memory beforeBytes = AddrResolver(LEGACY_L2_RESOLVER).addr(node, coinType);
        assertEq(beforeBytes.length, 0, "pre: ensip-11 addr already set");

        // Call MigrationController as owner (l2_owner_address)
        address ownerAddr = 0xdEC57186e5dB11CcFbb4C932b8f11bD86171CB9D;
        bytes32[] memory nodes = new bytes32[](1);
        nodes[0] = node;
        vm.prank(ownerAddr);
        MigrationController(MIGRATION_CONTROLLER).setBaseForwardAddr(nodes);

        // Post: ENSIP-11 (coinType) forward addr set
        bytes memory afterBytes = AddrResolver(LEGACY_L2_RESOLVER).addr(node, coinType);
        assertGt(afterBytes.length, 0, "post: ensip-11 addr not set");
    }

    function test_l2_reverse_registrar_with_migration_batchSetName() public {
        string memory name = "migraterev";

        // Claim/set old reverse name via legacy flow
        vm.prank(user);
        IReverseRegistrarLike(LEGACY_REVERSE_REGISTRAR).setNameForAddr(user, user, LEGACY_L2_RESOLVER, _fullName(name));

        address l2rr = ENS_L2_REVERSE_REGISTRAR;
        address rrOwner = IOwnable(l2rr).owner();

        address[] memory addrs = new address[](1);
        addrs[0] = user;

        vm.prank(rrOwner);
        IL2ReverseRegistrarWithMigration(l2rr).batchSetName(addrs);
    }
}

interface RegistrarControllerLike {
    struct RegisterRequest {
        string name;
        address owner;
        uint256 duration;
        address resolver;
        bytes[] data;
        bool reverseRecord;
    }

    function registerPrice(string memory name, uint256 duration) external view returns (uint256);
    function register(RegisterRequest calldata request) external payable;
}

interface IReverseRegistrarLike {
    function setNameForAddr(address addr, address owner, address resolver, string memory name)
        external
        returns (bytes32);
}
