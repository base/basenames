//SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {ReverseRegistrarV2Base} from "./ReverseRegistrarV2Base.t.sol";
import {ReverseRegistrarV2} from "src/L2/ReverseRegistrarV2.sol";
import {Sha3} from "src/lib/Sha3.sol";
import {BASE_REVERSE_NODE} from "src/util/Constants.sol";
import {NameResolver, MockNameResolver} from "test/mocks/MockNameResolver.sol";
import {MockOwnedContract} from "test/mocks/MockOwnedContract.sol";

contract SetNameForAddr is ReverseRegistrarV2Base {
    function test_allowsUser_toSetName_forUserAddress() public {
        bytes32 labelHash = Sha3.hexAddress(user);
        bytes32 baseReverseNode = keccak256(abi.encodePacked(BASE_REVERSE_NODE, labelHash));

        vm.prank(owner);
        reverse.setDefaultResolver(address(resolver));

        vm.expectEmit(address(reverse));
        emit ReverseRegistrarV2.BaseReverseClaimed(user, baseReverseNode);
        vm.prank(user);
        bytes32 returnedReverseNode = reverse.setNameForAddr(user, user, address(resolver), name);

        assertTrue(baseReverseNode == returnedReverseNode);
        address retBaseOwner = registry.owner(baseReverseNode);
        assertTrue(retBaseOwner == user);
        address retBaseResolver = registry.resolver(baseReverseNode);
        assertTrue(retBaseResolver == address(resolver));
        assertTrue(keccak256(abi.encode(resolver.name(baseReverseNode))) == keccak256(abi.encode(name)));
    }

    function test_allowsOperator_toSetName_forUserAddress() public {
        bytes32 labelHash = Sha3.hexAddress(user);
        bytes32 baseReverseNode = keccak256(abi.encodePacked(BASE_REVERSE_NODE, labelHash));

        address operator = makeAddr("operator");
        vm.prank(user);
        registry.setApprovalForAll(operator, true);

        vm.prank(owner);
        reverse.setDefaultResolver(address(resolver));

        vm.expectEmit(address(reverse));
        emit ReverseRegistrarV2.BaseReverseClaimed(user, baseReverseNode);
        vm.prank(operator);
        bytes32 returnedReverseNode = reverse.setNameForAddr(user, user, address(resolver), name);

        assertTrue(baseReverseNode == returnedReverseNode);
        address retBaseOwner = registry.owner(baseReverseNode);
        assertTrue(retBaseOwner == user);
        address retBaseResolver = registry.resolver(baseReverseNode);
        assertTrue(retBaseResolver == address(resolver));
        assertTrue(keccak256(abi.encode(resolver.name(baseReverseNode))) == keccak256(abi.encode(name)));
    }

    function test_allowsOwnerOfContract_toSetName_forOwnedContractAddress() public {
        MockOwnedContract ownedContract = new MockOwnedContract(user);
        bytes32 labelHash = Sha3.hexAddress(address(ownedContract));
        bytes32 baseReverseNode = keccak256(abi.encodePacked(BASE_REVERSE_NODE, labelHash));

        vm.expectEmit(address(reverse));
        emit ReverseRegistrarV2.BaseReverseClaimed(address(ownedContract), baseReverseNode);
        vm.prank(user);
        bytes32 returnedReverseNode = reverse.setNameForAddr(address(ownedContract), user, address(resolver), name);

        assertTrue(baseReverseNode == returnedReverseNode);
        address retBaseOwner = registry.owner(baseReverseNode);
        assertTrue(retBaseOwner == user);
        address retBaseResolver = registry.resolver(baseReverseNode);
        assertTrue(retBaseResolver == address(resolver));
        assertTrue(keccak256(abi.encode(resolver.name(baseReverseNode))) == keccak256(abi.encode(name)));
    }
}
