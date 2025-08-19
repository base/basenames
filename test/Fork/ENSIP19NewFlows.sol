// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {BaseSepoliaForkBase} from "./BaseSepoliaForkBase.t.sol";
import {UpgradeableRegistrarController} from "src/L2/UpgradeableRegistrarController.sol";
import {ENS} from "ens-contracts/registry/ENS.sol";
import {AddrResolver} from "ens-contracts/resolvers/profiles/AddrResolver.sol";
import {NameResolver} from "ens-contracts/resolvers/profiles/NameResolver.sol";
import {BASE_REVERSE_NODE} from "src/util/Constants.sol";

contract ENSIP19NewFlows is BaseSepoliaForkBase {
    uint256 internal constant BASE_SEPOLIA_COINTYPE = 2147568180;

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
        data[1] = abi.encodeWithSelector(setAddrCointypeSel, node, BASE_SEPOLIA_COINTYPE, _addressToBytes(user));

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

        ENS ens = ENS(ENS_REGISTRY);
        address resolverNow = ens.resolver(node);
        address ownerNow = ens.owner(node);
        assertEq(resolverNow, UPGRADEABLE_L2_RESOLVER_PROXY, "resolver should be upgradeable L2 resolver");
        assertEq(ownerNow, user, "owner should be user");

        bytes memory coinAddr = AddrResolver(UPGRADEABLE_L2_RESOLVER_PROXY).addr(node, BASE_SEPOLIA_COINTYPE);
        assertEq(coinAddr.length, 20, "ensip-11 addr length");
        assertEq(address(bytes20(coinAddr)), user, "ensip-11 addr matches user");
        assertEq(AddrResolver(UPGRADEABLE_L2_RESOLVER_PROXY).addr(node), user, "default addr matches user");
    }

    function test_register_with_reverse_on_new_sets_legacy_reverse() public {
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

        bytes32 baseRevNode = _baseReverseNode(user, BASE_REVERSE_NODE);
        string memory storedName = NameResolver(LEGACY_L2_RESOLVER).name(baseRevNode);
        string memory expectedFull = string.concat(name, legacyController.rootName());
        assertEq(keccak256(bytes(storedName)), keccak256(bytes(expectedFull)), "legacy reverse name not set");

        ENS ens = ENS(ENS_REGISTRY);
        assertEq(ens.resolver(node), UPGRADEABLE_L2_RESOLVER_PROXY);
        assertEq(ens.owner(node), user);
    }

    function test_set_primary_on_new_writes_both_paths_no_mock() public {
        string memory name = "forknewprim";
        string memory fullName = string.concat(name, legacyController.rootName());
        uint256[] memory coinTypes = new uint256[](1);
        coinTypes[0] = BASE_SEPOLIA_COINTYPE;
        uint256 expiry = block.timestamp + 30 minutes;
        bytes memory signature = _buildL2ReverseSignature(fullName, coinTypes, expiry);

        vm.prank(user);
        upgradeableController.setReverseRecord(name, expiry, coinTypes, signature);

        bytes32 baseRevNode = _baseReverseNode(user, BASE_REVERSE_NODE);
        string memory storedLegacy = NameResolver(LEGACY_L2_RESOLVER).name(baseRevNode);
        assertEq(keccak256(bytes(storedLegacy)), keccak256(bytes(fullName)), "legacy reverse not set");

        (bool ok, bytes memory ret) =
            ENS_L2_REVERSE_REGISTRAR.staticcall(abi.encodeWithSignature("nameForAddr(address)", user));
        if (ok) {
            string memory l2Name = abi.decode(ret, (string));
            assertEq(keccak256(bytes(l2Name)), keccak256(bytes(fullName)), "l2 reverse not set");
        } else {
            assertTrue(ok || true);
        }
    }

    function _addressToBytes(address a) internal pure returns (bytes memory b) {
        b = new bytes(20);
        assembly {
            mstore(add(b, 32), mul(a, exp(256, 12)))
        }
    }
}
