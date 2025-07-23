// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {UpgradeableRegistrarControllerBase} from "./UpgradeableRegistrarControllerBase.t.sol";
import {UpgradeableRegistrarController} from "src/L2/UpgradeableRegistrarController.sol";
import {IPriceOracle} from "src/L2/interface/IPriceOracle.sol";

contract DiscountedRegister is UpgradeableRegistrarControllerBase {
    function test_reverts_ifTheDiscountIsInactive() public {
        UpgradeableRegistrarController.DiscountDetails memory inactiveDiscount = _getDefaultDiscount();
        vm.deal(user, 1 ether);

        inactiveDiscount.active = false;
        vm.prank(owner);
        controller.setDiscountDetails(inactiveDiscount);
        uint256 price = controller.discountedRegisterPrice(name, duration, discountKey);

        vm.expectRevert(abi.encodeWithSelector(UpgradeableRegistrarController.InactiveDiscount.selector, discountKey));
        vm.prank(user);
        controller.discountedRegister{value: price}(_getDefaultRegisterRequest(), discountKey, "");
    }

    function test_reverts_whenInvalidDiscountRegistration() public {
        vm.deal(user, 1 ether);
        vm.prank(owner);
        controller.setDiscountDetails(_getDefaultDiscount());
        validator.setReturnValue(false);
        uint256 price = controller.discountedRegisterPrice(name, duration, discountKey);

        vm.expectRevert(
            abi.encodeWithSelector(UpgradeableRegistrarController.InvalidDiscount.selector, discountKey, "")
        );
        vm.prank(user);
        controller.discountedRegister{value: price}(_getDefaultRegisterRequest(), discountKey, "");
    }

    function test_reverts_whenNameNotValid() public {
        vm.deal(user, 1 ether);
        UpgradeableRegistrarController.RegisterRequest memory shortNameRequest = _getDefaultRegisterRequest();
        shortNameRequest.name = "a";
        uint256 price = controller.discountedRegisterPrice(shortNameRequest.name, duration, discountKey);

        vm.prank(owner);
        controller.setDiscountDetails(_getDefaultDiscount());
        validator.setReturnValue(true);
        base.setAvailable(uint256(nameLabel), true);

        vm.expectRevert(
            abi.encodeWithSelector(UpgradeableRegistrarController.NameNotValid.selector, shortNameRequest.name)
        );
        vm.prank(user);
        controller.discountedRegister{value: price}(shortNameRequest, discountKey, "");
    }

    function test_reverts_whenDurationTooShort() public {
        vm.deal(user, 1 ether);
        vm.prank(owner);
        controller.setDiscountDetails(_getDefaultDiscount());
        uint256 price = controller.discountedRegisterPrice(name, duration, discountKey);
        validator.setReturnValue(true);
        base.setAvailable(uint256(nameLabel), true);

        UpgradeableRegistrarController.RegisterRequest memory shortDurationRequest = _getDefaultRegisterRequest();
        uint256 shortDuration = controller.MIN_REGISTRATION_DURATION() - 1;
        shortDurationRequest.duration = shortDuration;
        vm.expectRevert(abi.encodeWithSelector(UpgradeableRegistrarController.DurationTooShort.selector, shortDuration));
        vm.prank(user);
        controller.discountedRegister{value: price}(shortDurationRequest, discountKey, "");
    }

    function test_reverts_whenValueTooSmall() public {
        vm.deal(user, 1 ether);
        vm.prank(owner);
        controller.setDiscountDetails(_getDefaultDiscount());
        prices.setPrice(name, IPriceOracle.Price({base: 1 ether, premium: 0}));
        uint256 price = controller.discountedRegisterPrice(name, duration, discountKey);
        validator.setReturnValue(true);
        base.setAvailable(uint256(nameLabel), true);

        vm.expectRevert(UpgradeableRegistrarController.InsufficientValue.selector);
        vm.prank(user);
        controller.discountedRegister{value: price - 1}(_getDefaultRegisterRequest(), discountKey, "");
    }

    function test_registersWithDiscountSuccessfully_withoutSignatureData() public {
        vm.deal(user, 1 ether);
        vm.prank(owner);
        controller.setDiscountDetails(_getDefaultDiscount());
        validator.setReturnValue(true);
        base.setAvailable(uint256(nameLabel), true);
        UpgradeableRegistrarController.RegisterRequest memory request = _getDefaultRegisterRequest();
        uint256 expires = block.timestamp + request.duration;
        base.setNameExpires(uint256(nameLabel), expires);
        uint256 price = controller.discountedRegisterPrice(name, duration, discountKey);

        vm.expectEmit(address(controller));
        emit UpgradeableRegistrarController.ETHPaymentProcessed(user, price);
        vm.expectEmit(address(controller));
        emit UpgradeableRegistrarController.NameRegistered(request.name, nameLabel, user, expires);
        vm.expectEmit(address(controller));
        emit UpgradeableRegistrarController.DiscountApplied(user, discountKey);

        vm.prank(user);
        controller.discountedRegister{value: price}(request, discountKey, "");

        bytes memory retByte = resolver.firstBytes();
        assertEq(keccak256(retByte), keccak256(request.data[0]));
        assertTrue(reverse.hasClaimed(user));
        assertFalse(l2ReverseRegistrar.hasClaimed());
        address[] memory addrs = new address[](1);
        addrs[0] = user;
        assertTrue(controller.hasRegisteredWithDiscount(addrs));
    }

    function test_registersWithDiscountSuccessfully_withSignatureData() public {
        vm.deal(user, 1 ether);
        vm.prank(owner);
        controller.setDiscountDetails(_getDefaultDiscount());
        validator.setReturnValue(true);
        base.setAvailable(uint256(nameLabel), true);
        UpgradeableRegistrarController.RegisterRequest memory request = _getDefaultRegisterRequest();
        uint256 expires = block.timestamp + request.duration;
        base.setNameExpires(uint256(nameLabel), expires);
        uint256 price = controller.discountedRegisterPrice(name, duration, discountKey);
        request.signatureExpiry = block.timestamp;
        request.signature = bytes("notempty");

        vm.expectEmit(address(controller));
        emit UpgradeableRegistrarController.ETHPaymentProcessed(user, price);
        vm.expectEmit(address(controller));
        emit UpgradeableRegistrarController.NameRegistered(request.name, nameLabel, user, expires);
        vm.expectEmit(address(controller));
        emit UpgradeableRegistrarController.DiscountApplied(user, discountKey);

        vm.prank(user);
        controller.discountedRegister{value: price}(request, discountKey, "");

        bytes memory retByte = resolver.firstBytes();
        assertEq(keccak256(retByte), keccak256(request.data[0]));
        assertTrue(reverse.hasClaimed(user));
        assertTrue(l2ReverseRegistrar.hasClaimed());
        address[] memory addrs = new address[](1);
        addrs[0] = user;
        assertTrue(controller.hasRegisteredWithDiscount(addrs));
    }

    function test_sendsARefund_ifUserOverpayed() public {
        vm.deal(user, 1 ether);
        vm.prank(owner);
        controller.setDiscountDetails(_getDefaultDiscount());
        validator.setReturnValue(true);
        base.setAvailable(uint256(nameLabel), true);
        UpgradeableRegistrarController.RegisterRequest memory request = _getDefaultRegisterRequest();
        uint256 expires = block.timestamp + request.duration;
        base.setNameExpires(uint256(nameLabel), expires);
        uint256 price = controller.discountedRegisterPrice(name, duration, discountKey);

        vm.prank(user);
        controller.discountedRegister{value: price + 1}(request, discountKey, "");

        uint256 expectedBalance = 1 ether - price;
        assertEq(user.balance, expectedBalance);
    }

    function test_reverts_ifTheRegistrantHasAlreadyRegisteredWithDiscount() public {
        vm.deal(user, 1 ether);
        vm.prank(owner);
        controller.setDiscountDetails(_getDefaultDiscount());
        validator.setReturnValue(true);
        base.setAvailable(uint256(nameLabel), true);
        UpgradeableRegistrarController.RegisterRequest memory request = _getDefaultRegisterRequest();
        uint256 expires = block.timestamp + request.duration;
        base.setNameExpires(uint256(nameLabel), expires);
        uint256 price = controller.discountedRegisterPrice(name, duration, discountKey);

        vm.prank(user);
        controller.discountedRegister{value: price}(request, discountKey, "");

        vm.expectRevert(
            abi.encodeWithSelector(UpgradeableRegistrarController.AlreadyRegisteredWithDiscount.selector, user)
        );
        request.name = "newname";
        vm.prank(user);
        controller.discountedRegister{value: price}(request, discountKey, "");
    }

    function test_reverts_ifTheRegistrantHasAlreadyRegisteredWithDiscountOnLegacy() public {
        vm.deal(user, 1 ether);
        vm.prank(owner);
        controller.setDiscountDetails(_getDefaultDiscount());
        validator.setReturnValue(true);
        base.setAvailable(uint256(nameLabel), true);
        UpgradeableRegistrarController.RegisterRequest memory request = _getDefaultRegisterRequest();
        uint256 expires = block.timestamp + request.duration;
        base.setNameExpires(uint256(nameLabel), expires);
        uint256 price = controller.discountedRegisterPrice(name, duration, discountKey);

        legacyController.setHasRegisteredWithDiscount(user, true);

        vm.expectRevert(
            abi.encodeWithSelector(UpgradeableRegistrarController.AlreadyRegisteredWithDiscount.selector, user)
        );
        request.name = "newname";
        vm.prank(user);
        controller.discountedRegister{value: price}(request, discountKey, "");
    }
}
