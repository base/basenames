// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {ENS} from "ens-contracts/registry/ENS.sol";
import {NameResolver} from "ens-contracts/resolvers/profiles/NameResolver.sol";

import {IReverseRegistrar} from "src/L2/interface/IReverseRegistrar.sol";
import {RegistrarController} from "src/L2/RegistrarController.sol";

import {AbstractForkSuite} from "./AbstractForkSuite.t.sol";

abstract contract AbstractENSIP19LegacyFlows is AbstractForkSuite {
    function test_register_name_on_legacy() public {
        string memory name = "forkleg";
        bytes32 root = legacyController.rootNode();
        bytes32 node = keccak256(abi.encodePacked(root, _labelFor(name)));

        RegistrarController.RegisterRequest memory req = RegistrarController.RegisterRequest({
            name: name,
            owner: user,
            duration: 365 days,
            resolver: LEGACY_L2_RESOLVER,
            data: new bytes[](0),
            reverseRecord: false
        });

        uint256 price = legacyController.registerPrice(name, req.duration);

        vm.deal(user, price);
        vm.startPrank(user);
        legacyController.register{value: price}(req);
        vm.stopPrank();

        // Assert resolver set on registry and owner assigned
        ENS ens = ENS(REGISTRY);
        address ownerNow = ens.owner(node);
        address resolverNow = ens.resolver(node);
        assertEq(ownerNow, user, "legacy owner");
        assertEq(resolverNow, LEGACY_L2_RESOLVER, "legacy resolver");
    }

    function test_set_primary_name_on_legacy() public {
        string memory name = "forkprimary";
        bytes32 root = legacyController.rootNode();
        bytes32 node = keccak256(abi.encodePacked(root, _labelFor(name)));

        // First register the name with a resolver and no reverse
        RegistrarController.RegisterRequest memory req = RegistrarController.RegisterRequest({
            name: name,
            owner: user,
            duration: 365 days,
            resolver: LEGACY_L2_RESOLVER,
            data: new bytes[](0),
            reverseRecord: false
        });
        uint256 price = legacyController.registerPrice(name, req.duration);
        vm.deal(user, price);
        vm.prank(user);
        legacyController.register{value: price}(req);

        // Set primary via legacy ReverseRegistrar directly (persist prank across nested calls)
        vm.startPrank(user);
        IReverseRegistrar(LEGACY_REVERSE_REGISTRAR).setNameForAddr(user, user, LEGACY_L2_RESOLVER, _fullName(name));
        vm.stopPrank();

        // Validate reverse record was set on the legacy resolver
        bytes32 baseRevNode = _baseReverseNode(user, baseReverseParentNode());
        string memory storedName = NameResolver(LEGACY_L2_RESOLVER).name(baseRevNode);
        assertEq(keccak256(bytes(storedName)), keccak256(bytes(_fullName(name))), "reverse name not set");

        // Forward resolver unchanged
        ENS ens = ENS(REGISTRY);
        assertEq(ens.resolver(node), LEGACY_L2_RESOLVER, "resolver unchanged");
    }

    function test_register_with_reverse_sets_primary_via_controller() public {
        string memory name = "forklegrev";
        bytes32 root = legacyController.rootNode();
        bytes32 node = keccak256(abi.encodePacked(root, _labelFor(name)));

        RegistrarController.RegisterRequest memory req = RegistrarController.RegisterRequest({
            name: name,
            owner: user,
            duration: 365 days,
            resolver: LEGACY_L2_RESOLVER,
            data: new bytes[](0),
            reverseRecord: true
        });

        uint256 price = legacyController.registerPrice(name, req.duration);
        vm.deal(user, price);
        vm.prank(user);
        legacyController.register{value: price}(req);

        // Assert reverse was set by the controller calling the ReverseRegistrar
        bytes32 baseRevNode = _baseReverseNode(user, baseReverseParentNode());
        string memory storedName = NameResolver(LEGACY_L2_RESOLVER).name(baseRevNode);
        string memory expectedFull = _fullName(name);
        assertEq(keccak256(bytes(storedName)), keccak256(bytes(expectedFull)), "reverse name not set by controller");

        // Also verify forward resolver/owner as a sanity check
        ENS ens = ENS(REGISTRY);
        assertEq(ens.owner(node), user);
        assertEq(ens.resolver(node), LEGACY_L2_RESOLVER);
    }
}
