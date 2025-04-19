// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {UpgradeableRegistrarControllerBase} from "./UpgradeableRegistrarControllerBase.t.sol";
import {UpgradeableRegistrarController} from "src/L2/UpgradeableRegistrarController.sol";
import {MockPriceOracle} from "test/mocks/MockPriceOracle.sol";
import {IPriceOracle} from "src/L2/interface/IPriceOracle.sol";
import {OwnableUpgradeable} from "openzeppelin-contracts-upgradeable/access/OwnableUpgradeable.sol";

contract SetPriceOracle is UpgradeableRegistrarControllerBase {
    function test_reverts_ifCalledByNonOwner(address caller) public whenNotProxyAdmin(caller, address(controller)) {
        vm.assume(caller != owner);
        MockPriceOracle newPrices = new MockPriceOracle();
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, caller));
        vm.prank(caller);
        controller.setPriceOracle(IPriceOracle(address(newPrices)));
    }

    function test_setsThePriceOracleAccordingly() public {
        vm.expectEmit();
        MockPriceOracle newPrices = new MockPriceOracle();
        emit UpgradeableRegistrarController.PriceOracleUpdated(address(newPrices));
        vm.prank(owner);
        controller.setPriceOracle(IPriceOracle(address(newPrices)));
        assertEq(address(controller.prices()), address(newPrices));
    }
}
