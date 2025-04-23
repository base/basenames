//SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {ReverseRegistrarShimBase} from "./ReverseRegistrarShimBase.t.sol";
import {MockL2ReverseRegistrar} from "test/mocks/MockL2ReverseRegistrar.sol";
import {MockReverseRegistrar} from "test/mocks/MockReverseRegistrar.sol";

contract SetNameForAddrWithSignature is ReverseRegistrarShimBase {
    function test_setsNameForAddr_onReverseRegistrar() public {
        vm.expectCall(
            address(revReg),
            abi.encodeCall(MockReverseRegistrar.setNameForAddr, (userA, userA, address(resolver), nameA))
        );
        vm.prank(userA);
        shim.setNameForAddrWithSignature(userA, nameA, signatureExpiry, cointypes, signature);
    }

    function test_setsNameForAddr_onL2ReverseRegistrar() public {
        vm.expectCall(
            address(l2RevReg),
            abi.encodeCall(
                MockL2ReverseRegistrar.setNameForAddrWithSignature,
                (userA, signatureExpiry, nameA, cointypes, signature)
            )
        );
        vm.prank(userA);
        shim.setNameForAddrWithSignature(userA, nameA, signatureExpiry, cointypes, signature);
    }
}
