//SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";

import {IntegrationTestBase} from "./IntegrationTestBase.t.sol";
import {MockL2ReverseRegistrar} from "test/mocks/MockL2ReverseRegistrar.sol";
import {MockReverseRegistrarV2} from "test/mocks/MockReverseRegistrarV2.sol";

import {ExponentialPremiumPriceOracle} from "src/L2/ExponentialPremiumPriceOracle.sol";
import {IPriceOracle} from "src/L2/interface/IPriceOracle.sol";
import {UpgradeableRegistrarController} from "src/L2/UpgradeableRegistrarController.sol";
import {TransparentUpgradeableProxy} from
    "openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import {BASE_ETH_NODE, GRACE_PERIOD} from "src/util/Constants.sol";

contract SwitchToUpgradeableRegistrarController is IntegrationTestBase {
    UpgradeableRegistrarController public controllerImpl;
    UpgradeableRegistrarController public controller;
    TransparentUpgradeableProxy public proxy;
    MockL2ReverseRegistrar public l2ReverseRegistrar;
    MockReverseRegistrarV2 public reverseRegistrarv2;

    address admin;
    uint256 duration = 365.25 days;

    uint256 constant UPGRADE_TIMESTAMP = 1746057600; // May 1 2025

    function setUp() public override {
        super.setUp();
        _registerAlice();

        vm.warp(UPGRADE_TIMESTAMP);

        admin = makeAddr("admin");

        l2ReverseRegistrar = new MockL2ReverseRegistrar();

        exponentialPremiumPriceOracle = new ExponentialPremiumPriceOracle(
            _getBasePrices(), EXPIRY_AUCTION_START_PRICE, EXPIRY_AUCTION_DURATION_DAYS
        );

        bytes memory controllerInitData = abi.encodeWithSelector(
            UpgradeableRegistrarController.initialize.selector,
            baseRegistrar,
            exponentialPremiumPriceOracle,
            reverseRegistrar,
            owner,
            BASE_ETH_NODE,
            ".base.eth",
            payments,
            address(registrarController),
            address(defaultL2Resolver),
            address(l2ReverseRegistrar)
        );

        controllerImpl = new UpgradeableRegistrarController();
        proxy = new TransparentUpgradeableProxy(address(controllerImpl), admin, controllerInitData);
        controller = UpgradeableRegistrarController(address(proxy));

        _postDeployConfig();
    }

    function _postDeployConfig() internal {
        vm.startPrank(owner);
        baseRegistrar.addController(address(proxy));
        reverseRegistrar.setControllerApproval(address(proxy), true);
        defaultL2Resolver.setRegistrarController(address(proxy));
        vm.stopPrank();
    }

    function test_canRegisterANewName() public {
        string memory name = "new-name";
        uint256[] memory coinTypes = new uint256[](1);
        coinTypes[0] = 0x80000000 | 0x00002105;

        uint256 registerPrice = controller.registerPrice(name, duration);
        uint256 expectedPrice = _getBasePrices()[4] * duration;
        vm.assertEq(registerPrice, expectedPrice);

        UpgradeableRegistrarController.RegisterRequest memory request = UpgradeableRegistrarController.RegisterRequest({
            name: name,
            owner: alice,
            duration: duration,
            resolver: address(defaultL2Resolver),
            data: new bytes[](0),
            reverseRecord: true,
            coinTypes: coinTypes,
            signatureExpiry: block.timestamp,
            signature: ""
        });

        vm.deal(alice, 1 ether);
        vm.prank(alice);
        controller.register{value: registerPrice}(request);
    }

    function test_canRenewExistingName() public {
        string memory name = "alice";

        IPriceOracle.Price memory prices = controller.rentPrice(name, duration);

        vm.deal(alice, 1 ether);
        vm.prank(alice);
        controller.renew{value: prices.base}(name, duration);
    }

    function test_canRenewNameInGracePeriod() public {
        string memory name = "alice";

        IPriceOracle.Price memory prices = controller.rentPrice(name, duration);

        vm.deal(alice, 1 ether);
        vm.warp(LAUNCH_TIME + duration + GRACE_PERIOD - 1);
        controller.renew{value: prices.base}(name, duration);
    }
}
