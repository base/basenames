// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {ENS} from "ens-contracts/registry/ENS.sol";
import {AddrResolver} from "ens-contracts/resolvers/profiles/AddrResolver.sol";
import {NameResolver} from "ens-contracts/resolvers/profiles/NameResolver.sol";

import {UpgradeableRegistrarController} from "src/L2/UpgradeableRegistrarController.sol";

import {AbstractForkSuite} from "./AbstractForkSuite.t.sol";

abstract contract AbstractENSIP19NewFlows is AbstractForkSuite {
    function test_register_on_new_sets_forward_records_ensip11() public {
        string memory name = "forknewfwd";
        bytes32 root = legacyController.rootNode();
        bytes32 node = keccak256(abi.encodePacked(root, keccak256(bytes(name))));

        bytes[] memory data = new bytes[](2);
        // setAddr(bytes32,address)
        bytes4 setAddrDefaultSel = bytes4(keccak256("setAddr(bytes32,address)"));
        data[0] = abi.encodeWithSelector(setAddrDefaultSel, node, user);
        // setAddr(bytes32,uint256,bytes)
        bytes4 setAddrCointypeSel = bytes4(keccak256("setAddr(bytes32,uint256,bytes)"));
        data[1] = abi.encodeWithSelector(setAddrCointypeSel, node, baseCoinType(), _addressToBytes(user));

        UpgradeableRegistrarController.RegisterRequest memory req = UpgradeableRegistrarController.RegisterRequest({
            name: name,
            owner: user,
            duration: 365 days,
            resolver: UPGRADEABLE_L2_RESOLVER_PROXY,
            data: data,
            reverseRecord: false,
            coinTypes: new uint256[](0),
            signatureExpiry: 0,
            signature: bytes("")
        });

        uint256 price = upgradeableController.registerPrice(name, req.duration);
        vm.deal(user, price);
        vm.prank(user);
        upgradeableController.register{value: price}(req);

        ENS ens = ENS(REGISTRY);
        address resolverNow = ens.resolver(node);
        address ownerNow = ens.owner(node);
        assertEq(resolverNow, UPGRADEABLE_L2_RESOLVER_PROXY, "resolver should be upgradeable L2 resolver");
        assertEq(ownerNow, user, "owner should be user");

        bytes memory coinAddr = AddrResolver(UPGRADEABLE_L2_RESOLVER_PROXY).addr(node, baseCoinType());
        assertEq(coinAddr.length, 20, "ensip-11 addr length");
        assertEq(address(bytes20(coinAddr)), user, "ensip-11 addr matches user");
        assertEq(AddrResolver(UPGRADEABLE_L2_RESOLVER_PROXY).addr(node), user, "default addr matches user");
    }

    function test_register_with_reverse_on_new_sets_only_legacy_reverse_no_signature() public {
        string memory name = "forknewrev";
        bytes32 root = legacyController.rootNode();
        bytes32 node = keccak256(abi.encodePacked(root, keccak256(bytes(name))));

        UpgradeableRegistrarController.RegisterRequest memory req = UpgradeableRegistrarController.RegisterRequest({
            name: name,
            owner: user,
            duration: 365 days,
            resolver: UPGRADEABLE_L2_RESOLVER_PROXY,
            data: new bytes[](0),
            reverseRecord: true,
            coinTypes: new uint256[](0),
            signatureExpiry: 0,
            signature: bytes("")
        });

        uint256 price = upgradeableController.registerPrice(name, req.duration);
        vm.deal(user, price);
        vm.prank(user);
        upgradeableController.register{value: price}(req);

        bytes32 baseRevNode = _baseReverseNode(user, baseReverseParentNode());
        string memory storedName = NameResolver(LEGACY_L2_RESOLVER).name(baseRevNode);
        string memory expectedFull = string.concat(name, legacyController.rootName());
        assertEq(keccak256(bytes(storedName)), keccak256(bytes(expectedFull)), "legacy reverse name not set");

        ENS ens = ENS(REGISTRY);
        assertEq(ens.resolver(node), UPGRADEABLE_L2_RESOLVER_PROXY);
        assertEq(ens.owner(node), user);

        // L2 reverse should NOT be set without signature
        string memory l2Name = l2ReverseRegistrar.nameForAddr(user);
        assertTrue(keccak256(bytes(l2Name)) != keccak256(bytes(expectedFull)), "l2 reverse should not be set");
    }

    function test_set_primary_on_new_writes_both_paths_with_signature() public {
        string memory name = "forknewprim";
        string memory fullName = _fullName(name);
        uint256[] memory coinTypes = new uint256[](1);
        coinTypes[0] = baseCoinType();
        uint256 expiry = block.timestamp + 30 minutes;
        bytes memory signature = _buildL2ReverseSignature(fullName, coinTypes, expiry);

        vm.prank(user);
        upgradeableController.setReverseRecord(name, expiry, coinTypes, signature);

        bytes32 baseRevNode = _baseReverseNode(user, baseReverseParentNode());
        string memory storedLegacy = NameResolver(LEGACY_L2_RESOLVER).name(baseRevNode);
        assertEq(keccak256(bytes(storedLegacy)), keccak256(bytes(fullName)), "legacy reverse not set");

        string memory l2Name = l2ReverseRegistrar.nameForAddr(user);
        assertEq(keccak256(bytes(l2Name)), keccak256(bytes(fullName)), "l2 reverse not set");
    }
}
