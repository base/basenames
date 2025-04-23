//SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Test} from "forge-std/Test.sol";
import {ReverseRegistrarShim} from "src/L2/ReverseRegistrarShim.sol";
import {MockReverseRegistrar} from "test/mocks/MockReverseRegistrar.sol";
import {MockL2ReverseRegistrar} from "test/mocks/MockL2ReverseRegistrar.sol";
import {MockPublicResolver} from "test/mocks/MockPublicResolver.sol";

contract ReverseRegistrarShimBase is Test {
    MockL2ReverseRegistrar l2RevReg;
    MockReverseRegistrar revReg;
    MockPublicResolver resolver;

    ReverseRegistrarShim public shim;

    address userA;
    address userB;
    string nameA = "userAName";
    string nameB = "userBName";

    uint256 signatureExpiry = 0;
    bytes signature;
    uint256[] cointypes;

    function setUp() external {
        l2RevReg = new MockL2ReverseRegistrar();
        revReg = new MockReverseRegistrar();
        resolver = new MockPublicResolver();
        shim = new ReverseRegistrarShim(address(revReg), address(l2RevReg), address(resolver));

        userA = makeAddr("userA");
        userB = makeAddr("userB");
    }
}
