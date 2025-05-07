//SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {ReverseRegistrarV2Base} from "./ReverseRegistrarV2Base.t.sol";
import {ReverseRegistrarV2} from "src/L2/ReverseRegistrarV2.sol";
import {Sha3} from "src/lib/Sha3.sol";
import {BASE_REVERSE_NODE} from "src/util/Constants.sol";

contract Claim is ReverseRegistrarV2Base {
    function test_allowsUser_toClaim() public {
        bytes32 labelHash = Sha3.hexAddress(user);
        bytes32 baseReverseNode = keccak256(abi.encodePacked(BASE_REVERSE_NODE, labelHash));

        vm.prank(owner);
        reverse.setDefaultResolver(address(resolver));

        vm.expectEmit(address(reverse));
        emit ReverseRegistrarV2.BaseReverseClaimed(user, baseReverseNode);

        vm.prank(user);
        bytes32 returnedReverseNode = reverse.claim(user);

        assertTrue(baseReverseNode == returnedReverseNode);
        address retBaseOwner = registry.owner(baseReverseNode);
        assertTrue(retBaseOwner == user);
        address retBaseResolver = registry.resolver(baseReverseNode);
        assertTrue(retBaseResolver == address(resolver));
    }
}
