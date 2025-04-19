//SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {ReverseRegistrarShimBase} from "./ReverseRegistrarShimBase.t.sol";
import {MockReverseRegistrar} from "test/mocks/MockReverseRegistrar.sol";
import {MockReverseResolver} from "test/mocks/MockReverseResolver.sol";

contract SetNameForAddrWithSignature is ReverseRegistrarShimBase {
    function test_setsNameForAddr_onReverseRegistrar() public {
        vm.prank(userA);
        vm.expectCall(
            address(revReg),
            abi.encodeWithSelector(MockReverseRegistrar.setNameForAddr.selector, userA, userA, address(resolver), nameA)
        );
        shim.setNameForAddrWithSignature(userA, nameA, signatureExpiry, signature);
    }

    function test_setsNameForAddr_onReverseResolver() public {
        vm.prank(userA);
        vm.expectCall(
            address(revRes),
            abi.encodeWithSelector(
                MockReverseResolver.setNameForAddrWithSignature.selector, userA, nameA, signatureExpiry, signature
            )
        );
        shim.setNameForAddrWithSignature(userA, nameA, signatureExpiry, signature);
    }
}
