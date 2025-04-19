// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {UpgradeableRegistrarControllerBase} from "./UpgradeableRegistrarControllerBase.t.sol";
import {UpgradeableRegistrarController} from "src/L2/UpgradeableRegistrarController.sol";
import {IPriceOracle} from "src/L2/interface/IPriceOracle.sol";
import {OwnableUpgradeable} from "openzeppelin-contracts-upgradeable/access/OwnableUpgradeable.sol";
import {MockUSDC} from "test/mocks/MockUSDC.sol";

contract RecoverFunds is UpgradeableRegistrarControllerBase {
    MockUSDC public usdc;

    function test_reverts_ifCalledByNonOwner(address caller, uint256 amount)
        public
        whenNotProxyAdmin(caller, address(controller))
    {
        vm.assume(caller != owner); // Ownable owner
        vm.assume(amount > 0 && amount < type(uint128).max);
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, caller));
        vm.prank(caller);
        controller.recoverFunds(address(usdc), caller, amount);
    }

    function test_allowsTheOwnerToRecoverFunds(uint256 amount) public {
        vm.assume(amount > 0 && amount < type(uint128).max);
        _setupTokenAndAssignBalanceToController(amount);
        assertEq(usdc.balanceOf(owner), 0);

        vm.prank(owner);
        controller.recoverFunds(address(usdc), owner, amount);
        assertEq(usdc.balanceOf(owner), amount);
    }

    function _setupTokenAndAssignBalanceToController(uint256 balance) internal {
        usdc = new MockUSDC();
        usdc.mint(address(controller), balance);
    }
}
