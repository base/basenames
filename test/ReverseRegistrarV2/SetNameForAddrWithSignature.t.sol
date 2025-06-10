//SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {ReverseRegistrarV2} from "src/L2/ReverseRegistrarV2.sol";
import {ReverseRegistrarV2Base} from "./ReverseRegistrarV2Base.t.sol";
import {MockL2ReverseRegistrar} from "test/mocks/MockL2ReverseRegistrar.sol";
import {MockReverseRegistrar} from "test/mocks/MockReverseRegistrar.sol";
import {BASE_REVERSE_NODE} from "src/util/Constants.sol";
import {Sha3} from "src/lib/Sha3.sol";

contract SetNameForAddrWithSignature is ReverseRegistrarV2Base {
    function test_setsNameForAddrWithSignature() public {
        uint256[] memory cointypes = new uint256[](1);
        cointypes[0] = BASE_COINTYPE;
        bytes memory signature = "";
        uint256 expiry = block.timestamp + 5 minutes;

        vm.prank(owner);
        reverse.setDefaultResolver(address(resolver));

        bytes32 labelHash = Sha3.hexAddress(user);
        bytes32 baseReverseNode = keccak256(abi.encodePacked(BASE_REVERSE_NODE, labelHash));

        vm.expectCall(
            address(l2ReverseRegistrar),
            abi.encodeCall(
                MockL2ReverseRegistrar.setNameForAddrWithSignature, (user, expiry, name, cointypes, signature)
            )
        );
        vm.prank(user);

        bytes32 revNode = reverse.setNameForAddrWithSignature(user, expiry, name, cointypes, signature);
        assertEq(revNode, baseReverseNode);
    }
}
