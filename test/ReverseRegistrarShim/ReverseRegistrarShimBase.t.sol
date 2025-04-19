//SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Test} from "forge-std/Test.sol";
import {ReverseRegistrarShim} from "src/L2/ReverseRegistrarShim.sol";
import {MockReverseRegistrar} from "test/mocks/MockReverseRegistrar.sol";
import {MockReverseResolver} from "test/mocks/MockReverseResolver.sol";
import {MockPublicResolver} from "test/mocks/MockPublicResolver.sol";

contract ReverseRegistrarShimBase is Test {
    MockReverseResolver revRes;
    MockReverseRegistrar revReg;
    MockPublicResolver resolver;

    ReverseRegistrarShim public shim;

    address userA;
    address userB;
    string nameA = "userAName";
    string nameB = "userBName";

    uint256 signatureExpiry = 0;
    bytes signature;

    function setUp() external {
        revRes = new MockReverseResolver();
        revReg = new MockReverseRegistrar();
        resolver = new MockPublicResolver();
        shim = new ReverseRegistrarShim(address(revReg), address(revRes), address(resolver));

        userA = makeAddr("userA");
        userB = makeAddr("userB");
    }
}
