// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {BaseSepoliaForkBase} from "./BaseSepoliaForkBase.t.sol";
import {MigrationController} from "src/L2/MigrationController.sol";
import {ENS} from "ens-contracts/registry/ENS.sol";
import {AddrResolver} from "ens-contracts/resolvers/profiles/AddrResolver.sol";
import {RegistrarController} from "src/L2/RegistrarController.sol";
import {ReverseRegistrar} from "src/L2/ReverseRegistrar.sol";
import {L2Resolver} from "src/L2/L2Resolver.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {BASE_REVERSE_NODE} from "src/util/Constants.sol";
import {NameResolver} from "ens-contracts/resolvers/profiles/NameResolver.sol";

contract ENSIP19DataMigrations is BaseSepoliaForkBase {
    address internal constant MIGRATION_CONTROLLER = 0xE8A87034a06425476F2bD6fD14EA038332Cc5e10;
    address internal constant L2_OWNER = 0xdEC57186e5dB11CcFbb4C932b8f11bD86171CB9D;

    function test_migration_controller_setBaseForwardAddr() public {
        string memory name = "migratefwd";
        bytes32 root = legacyController.rootNode();
        bytes32 node = keccak256(abi.encodePacked(root, _labelFor(name)));

        // Register a name with legacy resolver
        RegistrarController legacyRC = RegistrarController(LEGACY_GA_CONTROLLER);
        uint256 price = legacyRC.registerPrice(name, 365 days);
        vm.deal(user, price);
        vm.prank(user);
        legacyRC.register{value: price}(
            RegistrarController.RegisterRequest({
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

        // Configure MigrationController as registrar controller on the resolver (as L2 owner)
        vm.prank(L2_OWNER);
        L2Resolver(LEGACY_L2_RESOLVER).setRegistrarController(MIGRATION_CONTROLLER);

        uint256 coinType = MigrationController(MIGRATION_CONTROLLER).coinType();

        // Pre: ENSIP-11 (coinType) record should be empty
        bytes memory beforeBytes = AddrResolver(LEGACY_L2_RESOLVER).addr(node, coinType);
        assertEq(beforeBytes.length, 0, "pre: ensip-11 addr already set");

        // Call MigrationController as owner (l2_owner_address)
        bytes32[] memory nodes = new bytes32[](1);
        nodes[0] = node;
        vm.prank(L2_OWNER);
        MigrationController(MIGRATION_CONTROLLER).setBaseForwardAddr(nodes);

        // Post: ENSIP-11 (coinType) forward addr set
        bytes memory afterBytes = AddrResolver(LEGACY_L2_RESOLVER).addr(node, coinType);
        assertGt(afterBytes.length, 0, "post: ensip-11 addr not set");
    }

    function test_l2_reverse_registrar_with_migration_batchSetName() public {
        string memory name = "migraterev";

        // Claim/set old reverse name via legacy flow
        vm.prank(user);
        ReverseRegistrar(LEGACY_REVERSE_REGISTRAR).setNameForAddr(user, user, LEGACY_L2_RESOLVER, _fullName(name));

        address rrOwner = Ownable(ENS_L2_REVERSE_REGISTRAR).owner();

        address[] memory addrs = new address[](1);
        addrs[0] = user;

        vm.prank(rrOwner);
        l2ReverseRegistrar.batchSetName(addrs);

        // Assert L2 reverse registrar stored the migrated name
        string memory l2Name = l2ReverseRegistrar.nameForAddr(user);
        assertEq(keccak256(bytes(l2Name)), keccak256(bytes(_fullName(name))), "l2 reverse name not migrated");
    }
}
