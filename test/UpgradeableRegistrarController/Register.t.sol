// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {UpgradeableRegistrarControllerBase} from "./UpgradeableRegistrarControllerBase.t.sol";
import {UpgradeableRegistrarController} from "src/L2/UpgradeableRegistrarController.sol";
import {IPriceOracle} from "src/L2/interface/IPriceOracle.sol";

contract Register is UpgradeableRegistrarControllerBase {
    function test_reverts_whenResolverRequiredAndNotSupplied() public {
        vm.deal(user, 1 ether);
        uint256 price = controller.registerPrice(name, duration);
        vm.expectRevert(UpgradeableRegistrarController.ResolverRequiredWhenDataSupplied.selector);
        vm.prank(user);
        UpgradeableRegistrarController.RegisterRequest memory noResolverRequest = _getDefaultRegisterRequest();
        noResolverRequest.resolver = address(0);
        controller.register{value: price}(noResolverRequest);
    }

    function test_reverts_whenNameNotValid() public {
        vm.deal(user, 1 ether);
        UpgradeableRegistrarController.RegisterRequest memory shortNameRequest = _getDefaultRegisterRequest();
        shortNameRequest.name = "a";
        uint256 price = controller.registerPrice(shortNameRequest.name, duration);
        vm.expectRevert(
            abi.encodeWithSelector(UpgradeableRegistrarController.NameNotValid.selector, shortNameRequest.name)
        );
        vm.prank(user);
        controller.register{value: price}(shortNameRequest);
    }

    function test_reverts_whenDurationTooShort() public {
        vm.deal(user, 1 ether);
        uint256 price = controller.registerPrice(name, duration);
        base.setAvailable(uint256(nameLabel), true);
        UpgradeableRegistrarController.RegisterRequest memory shortDurationRequest = _getDefaultRegisterRequest();
        uint256 shortDuration = controller.MIN_REGISTRATION_DURATION() - 1;
        shortDurationRequest.duration = shortDuration;
        vm.expectRevert(abi.encodeWithSelector(UpgradeableRegistrarController.DurationTooShort.selector, shortDuration));
        vm.prank(user);
        controller.register{value: price}(shortDurationRequest);
    }

    function test_reverts_whenValueTooSmall() public {
        vm.deal(user, 1 ether);
        uint256 price = controller.registerPrice(name, duration);
        base.setAvailable(uint256(nameLabel), true);
        vm.expectRevert(UpgradeableRegistrarController.InsufficientValue.selector);
        vm.prank(user);
        controller.register{value: price - 1}(_getDefaultRegisterRequest());
    }

    function test_registersSuccessfully_withoutSignatureData() public {
        vm.deal(user, 1 ether);
        UpgradeableRegistrarController.RegisterRequest memory request = _getDefaultRegisterRequest();

        base.setAvailable(uint256(nameLabel), true);
        uint256 expires = block.timestamp + request.duration;
        base.setNameExpires(uint256(nameLabel), expires);
        uint256 price = controller.registerPrice(request.name, request.duration);

        vm.expectEmit(address(controller));
        emit UpgradeableRegistrarController.ETHPaymentProcessed(user, price);
        vm.expectEmit(address(controller));
        emit UpgradeableRegistrarController.NameRegistered(request.name, nameLabel, user, expires);

        vm.prank(user);
        controller.register{value: price}(request);

        bytes memory retByte = resolver.firstBytes();
        assertEq(keccak256(retByte), keccak256(request.data[0]));
        assertTrue(reverse.hasClaimed(user));
        assertFalse(l2ReverseRegistrar.hasClaimed());
    }

    function test_registersSuccessfully_withSignatureData() public {
        vm.deal(user, 1 ether);
        UpgradeableRegistrarController.RegisterRequest memory request = _getDefaultRegisterRequest();

        base.setAvailable(uint256(nameLabel), true);
        uint256 expires = block.timestamp + request.duration;
        base.setNameExpires(uint256(nameLabel), expires);
        uint256 price = controller.registerPrice(request.name, request.duration);

        request.signatureExpiry = block.timestamp;
        request.signature = bytes("notempty");

        vm.expectEmit(address(controller));
        emit UpgradeableRegistrarController.ETHPaymentProcessed(user, price);
        vm.expectEmit(address(controller));
        emit UpgradeableRegistrarController.NameRegistered(request.name, nameLabel, user, expires);

        vm.prank(user);
        controller.register{value: price}(request);

        bytes memory retByte = resolver.firstBytes();
        assertEq(keccak256(retByte), keccak256(request.data[0]));
        assertTrue(reverse.hasClaimed(user));
        assertTrue(l2ReverseRegistrar.hasClaimed());
    }

    function test_sendsARefund_ifUserOverpayed() public {
        vm.deal(user, 1 ether);
        UpgradeableRegistrarController.RegisterRequest memory request = _getDefaultRegisterRequest();

        base.setAvailable(uint256(nameLabel), true);
        uint256 expires = block.timestamp + request.duration;
        base.setNameExpires(uint256(nameLabel), expires);
        uint256 price = controller.registerPrice(request.name, request.duration);

        vm.prank(user);
        controller.register{value: price + 1}(request);

        uint256 expectedBalance = 1 ether - price;
        assertEq(user.balance, expectedBalance);
    }
}
