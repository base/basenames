// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {UpgradeableRegistrarControllerBase} from "./UpgradeableRegistrarControllerBase.t.sol";
import {UpgradeableRegistrarController} from "src/L2/UpgradeableRegistrarController.sol";
import {IPriceOracle} from "src/L2/interface/IPriceOracle.sol";

contract WithdrawETH is UpgradeableRegistrarControllerBase {
    function test_alwaysSendsTheBalanceToTheOwner(address caller)
        public
        whenNotProxyAdmin(caller, address(controller))
    {
        vm.deal(address(controller), 1 ether);
        assertEq(payments.balance, 0);
        vm.prank(caller);
        controller.withdrawETH();
        assertEq(payments.balance, 1 ether);
    }
}
