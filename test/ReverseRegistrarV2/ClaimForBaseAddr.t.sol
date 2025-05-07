//SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {ReverseRegistrarV2Base} from "./ReverseRegistrarV2Base.t.sol";
import {ReverseRegistrarV2} from "src/L2/ReverseRegistrarV2.sol";
import {Sha3} from "src/lib/Sha3.sol";
import {BASE_REVERSE_NODE} from "src/util/Constants.sol";
import {MockOwnedContract} from "test/mocks/MockOwnedContract.sol";

contract ClaimForBaseAddr is ReverseRegistrarV2Base {
    function test_reverts_ifNotAuthorized() public {
        address revRecordAddr = makeAddr("revRecord");
        vm.expectRevert(abi.encodeWithSelector(ReverseRegistrarV2.NotAuthorized.selector, revRecordAddr, user));
        vm.prank(user);
        reverse.claimForBaseAddr(revRecordAddr, user, address(resolver));
    }

    function test_allowsUser_toclaimForBaseAddr_forUserAddress() public {
        bytes32 labelHash = Sha3.hexAddress(user);
        bytes32 reverseNode = keccak256(abi.encodePacked(BASE_REVERSE_NODE, labelHash));

        vm.expectEmit(address(reverse));
        emit ReverseRegistrarV2.BaseReverseClaimed(user, reverseNode);
        vm.prank(user);
        bytes32 returnedReverseNode = reverse.claimForBaseAddr(user, user, address(resolver));
        assertTrue(reverseNode == returnedReverseNode);
        address retOwner = registry.owner(reverseNode);
        assertTrue(retOwner == user);
        address retResolver = registry.resolver(reverseNode);
        assertTrue(retResolver == address(resolver));
    }

    function test_allowsOperator_toclaimForBaseAddr_forUserAddress() public {
        bytes32 labelHash = Sha3.hexAddress(user);
        bytes32 reverseNode = keccak256(abi.encodePacked(BASE_REVERSE_NODE, labelHash));
        address operator = makeAddr("operator");
        vm.prank(user);
        registry.setApprovalForAll(operator, true);

        vm.expectEmit(address(reverse));
        emit ReverseRegistrarV2.BaseReverseClaimed(user, reverseNode);
        vm.prank(operator);
        bytes32 returnedReverseNode = reverse.claimForBaseAddr(user, user, address(resolver));
        assertTrue(reverseNode == returnedReverseNode);
        address retOwner = registry.owner(reverseNode);
        assertTrue(retOwner == user);
        address retResolver = registry.resolver(reverseNode);
        assertTrue(retResolver == address(resolver));
    }

    function test_allowsOwnerOfContract_toclaimForBaseAddr_forOwnedContractAddress() public {
        MockOwnedContract ownedContract = new MockOwnedContract(user);
        bytes32 labelHash = Sha3.hexAddress(address(ownedContract));
        bytes32 reverseNode = keccak256(abi.encodePacked(BASE_REVERSE_NODE, labelHash));

        vm.expectEmit(address(reverse));
        emit ReverseRegistrarV2.BaseReverseClaimed(address(ownedContract), reverseNode);
        vm.prank(user);
        bytes32 returnedReverseNode = reverse.claimForBaseAddr(address(ownedContract), user, address(resolver));
        assertTrue(reverseNode == returnedReverseNode);
        address retOwner = registry.owner(reverseNode);
        assertTrue(retOwner == user);
        address retResolver = registry.resolver(reverseNode);
        assertTrue(retResolver == address(resolver));
    }
}
