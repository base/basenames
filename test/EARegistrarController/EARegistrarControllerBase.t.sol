// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Test} from "forge-std/Test.sol";
import {EARegistrarController} from "src/L2/EARegistrarController.sol";
import {IPriceOracle} from "src/L2/interface/IPriceOracle.sol";
import {BaseRegistrar} from "src/L2/BaseRegistrar.sol";
import {Registry} from "src/L2/Registry.sol";
import {IReverseRegistrar} from "src/L2/interface/IReverseRegistrar.sol";
import {ENS} from "ens-contracts/registry/ENS.sol";

import {MockBaseRegistrar} from "test/mocks/MockBaseRegistrar.sol";
import {MockReverseRegistrar} from "test/mocks/MockReverseRegistrar.sol";
import {MockNameWrapper} from "test/mocks/MockNameWrapper.sol";
import {MockPriceOracle} from "test/mocks/MockPriceOracle.sol";
import {MockDiscountValidator} from "test/mocks/MockDiscountValidator.sol";
import {MockPublicResolver} from "test/mocks/MockPublicResolver.sol";
import {BASE_ETH_NODE, REVERSE_NODE} from "src/util/Constants.sol";

contract EARegistrarControllerBase is Test {
    EARegistrarController public controller;
    MockBaseRegistrar public base;
    MockReverseRegistrar public reverse;
    MockPriceOracle public prices;
    Registry public registry;
    MockPublicResolver public resolver;

    address owner = makeAddr("owner");
    address user = makeAddr("user");
    address payments = makeAddr("payments");

    bytes32 public rootNode = BASE_ETH_NODE;
    string public rootName = ".base.eth";
    string public name = "test";
    string public shortName = "t";
    bytes32 public nameLabel = keccak256(bytes(name));
    bytes32 public shortNameLabel = keccak256(bytes(shortName));

    MockDiscountValidator public validator;
    bytes32 public discountKey = keccak256(bytes("default.discount"));
    uint256 discountAmount = 0.1 ether;
    uint256 duration = 365 days;

    function setUp() public {
        base = new MockBaseRegistrar();
        reverse = new MockReverseRegistrar();
        prices = new MockPriceOracle();
        registry = new Registry(owner);
        resolver = new MockPublicResolver();
        validator = new MockDiscountValidator();

        _establishNamespace();

        vm.prank(owner);
        controller = new EARegistrarController(
            BaseRegistrar(address(base)),
            IPriceOracle(address(prices)),
            IReverseRegistrar(address(reverse)),
            owner,
            rootNode,
            rootName,
            payments
        );
    }

    function test_controller_constructor() public view {
        assertEq(address(controller.prices()), address(prices));
        assertEq(address(controller.reverseRegistrar()), address(reverse));
        assertEq(controller.owner(), owner);
        assertEq(controller.rootNode(), rootNode);
        assertEq(keccak256(bytes(controller.rootName())), keccak256(bytes(rootName)));
    }

    function _establishNamespace() internal virtual {}

    function _getDefaultDiscount() internal view returns (EARegistrarController.DiscountDetails memory) {
        return EARegistrarController.DiscountDetails({
            active: true, discountValidator: address(validator), key: discountKey, discount: discountAmount
        });
    }

    function _getDefaultRegisterRequest() internal view virtual returns (EARegistrarController.RegisterRequest memory) {
        return EARegistrarController.RegisterRequest({
            name: name,
            owner: user,
            duration: duration,
            resolver: address(resolver),
            data: _getDefaultRegisterData(),
            reverseRecord: true
        });
    }

    function _getDefaultRegisterData() internal view virtual returns (bytes[] memory data) {
        data = new bytes[](1);
        data[0] = bytes(name);
    }
}
