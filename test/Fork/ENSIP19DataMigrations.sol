// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {NameResolver} from "ens-contracts/resolvers/profiles/NameResolver.sol";
import {NameEncoder} from "ens-contracts/utils/NameEncoder.sol";
import {ENS} from "ens-contracts/registry/ENS.sol";
import {AddrResolver} from "ens-contracts/resolvers/profiles/AddrResolver.sol";
import {console2} from "forge-std/console2.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {RegistrarController} from "src/L2/RegistrarController.sol";
import {ReverseRegistrar} from "src/L2/ReverseRegistrar.sol";
import {L2Resolver} from "src/L2/L2Resolver.sol";
import {BASE_REVERSE_NODE} from "src/util/Constants.sol";
import {MigrationController} from "src/L2/MigrationController.sol";
import {Sha3} from "src/lib/Sha3.sol";

import {BaseSepoliaForkBase} from "./BaseSepoliaForkBase.t.sol";
import {BaseSepolia as BaseSepoliaConstants} from "test/Fork/BaseSepoliaConstants.sol";

contract ENSIP19DataMigrations is BaseSepoliaForkBase {
    function test_migration_controller_setBaseForwardAddr() public {
        string memory name = "migratefwd";
        bytes32 root = legacyController.rootNode();
        bytes32 node = keccak256(abi.encodePacked(root, _labelFor(name)));

        // Register a name with legacy resolver
        RegistrarController legacyRC = RegistrarController(BaseSepoliaConstants.LEGACY_GA_CONTROLLER);
        uint256 price = legacyRC.registerPrice(name, 365 days);
        vm.deal(user, price);
        vm.prank(user);
        legacyRC.register{value: price}(
            RegistrarController.RegisterRequest({
                name: name,
                owner: user,
                duration: 365 days,
                resolver: BaseSepoliaConstants.LEGACY_L2_RESOLVER,
                data: new bytes[](0),
                reverseRecord: false
            })
        );

        // Set a legacy EVM addr record (ETH_COINTYPE) on the resolver so there is something to migrate
        vm.prank(user);
        AddrResolver(BaseSepoliaConstants.LEGACY_L2_RESOLVER).setAddr(node, user);

        // Configure MigrationController as registrar controller on the resolver (as L2 owner)
        vm.prank(L2_OWNER);
        L2Resolver(BaseSepoliaConstants.LEGACY_L2_RESOLVER).setRegistrarController(
            BaseSepoliaConstants.MIGRATION_CONTROLLER
        );

        uint256 coinType = MigrationController(BaseSepoliaConstants.MIGRATION_CONTROLLER).coinType();

        // Pre: ENSIP-11 (coinType) record should be empty
        bytes memory beforeBytes = AddrResolver(BaseSepoliaConstants.LEGACY_L2_RESOLVER).addr(node, coinType);
        assertEq(beforeBytes.length, 0, "pre: ensip-11 addr already set");

        // Call MigrationController as owner (l2_owner_address)
        bytes32[] memory nodes = new bytes32[](1);
        nodes[0] = node;
        vm.prank(L2_OWNER);
        MigrationController(BaseSepoliaConstants.MIGRATION_CONTROLLER).setBaseForwardAddr(nodes);

        // Post: ENSIP-11 (coinType) forward addr set
        bytes memory afterBytes = AddrResolver(BaseSepoliaConstants.LEGACY_L2_RESOLVER).addr(node, coinType);
        assertGt(afterBytes.length, 0, "post: ensip-11 addr not set");
    }

    function test_l2_reverse_registrar_with_migration_batchSetName() public {
        string memory name = "migraterev";

        // Claim/set old reverse name via legacy flow
        vm.prank(user);
        ReverseRegistrar(BaseSepoliaConstants.LEGACY_REVERSE_REGISTRAR).setNameForAddr(
            user, user, BaseSepoliaConstants.LEGACY_L2_RESOLVER, _fullName(name)
        );

        address rrOwner = Ownable(ENS_L2_REVERSE_REGISTRAR).owner();

        address[] memory addrs = new address[](1);
        addrs[0] = user;

        (, bytes32 calculatedBaseReverseNode) = NameEncoder.dnsEncodeName("80014a34.reverse");
        console2.logBytes32(calculatedBaseReverseNode);
        bytes32 node = keccak256(abi.encodePacked(calculatedBaseReverseNode, Sha3.hexAddress(user)));
        console2.logBytes32(node);

        vm.prank(rrOwner);
        l2ReverseRegistrar.batchSetName(addrs);

        // Assert L2 reverse registrar stored the migrated name
        string memory l2Name = l2ReverseRegistrar.nameForAddr(user);
        assertEq(keccak256(bytes(l2Name)), keccak256(bytes(_fullName(name))), "l2 reverse name not migrated");
    }
}
