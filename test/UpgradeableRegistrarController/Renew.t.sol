// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {UpgradeableRegistrarControllerBase} from "./UpgradeableRegistrarControllerBase.t.sol";
import {UpgradeableRegistrarController} from "src/L2/UpgradeableRegistrarController.sol";
import {IPriceOracle} from "src/L2/interface/IPriceOracle.sol";

contract Renew is UpgradeableRegistrarControllerBase {
    function test_allowsAUserToRenewTheirName() public {
        vm.deal(user, 1 ether);
        (uint256 expires,) = _register();
        IPriceOracle.Price memory price = controller.rentPrice(name, duration);
        uint256 newExpiry = expires + duration;

        vm.expectEmit(address(controller));
        emit UpgradeableRegistrarController.ETHPaymentProcessed(user, price.base);
        vm.expectEmit(address(controller));
        emit UpgradeableRegistrarController.NameRenewed(name, nameLabel, newExpiry);

        vm.prank(user);
        controller.renew{value: price.base}(name, duration);
    }

    function test_refundsExcessETH_onOverpaidRenewal() public {
        vm.deal(user, 1 ether);
        (, uint256 registerPrice) = _register();
        IPriceOracle.Price memory price = controller.rentPrice(name, duration);

        vm.prank(user);
        controller.renew{value: (price.base + 1)}(name, duration);

        uint256 expectedBalance = 1 ether - registerPrice - price.base;
        assertEq(user.balance, expectedBalance);
    }

    function _register() internal returns (uint256, uint256) {
        UpgradeableRegistrarController.RegisterRequest memory request = _getDefaultRegisterRequest();
        uint256 price = controller.registerPrice(request.name, request.duration);
        base.setAvailable(uint256(nameLabel), true);
        uint256 expires = block.timestamp + request.duration;
        base.setNameExpires(uint256(nameLabel), expires);
        vm.prank(user);
        controller.register{value: price}(request);
        return (expires, price);
    }
}
