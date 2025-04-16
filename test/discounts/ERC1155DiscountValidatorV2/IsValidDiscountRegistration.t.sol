//SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {ERC1155DiscountValidatorV2Base} from "./ERC1155DiscountValidatorV2Base.t.sol";

contract IsValidDiscountRegistration is ERC1155DiscountValidatorV2Base {
    function test_returnsTrue_whenTheUserHasOneToken() public {
        uint256[] memory tokensToTest = new uint256[](1);
        tokensToTest[0] = firstValidTokenId;
        token.mint(userA, firstValidTokenId, 1);
        assertTrue(validator.isValidDiscountRegistration(userA, abi.encode(tokensToTest)));
    }

    function test_returnsTrue_whenTheUserHasOneTokenProvidingMultipleIds() public {
        uint256[] memory tokensToTest = new uint256[](2);
        tokensToTest[0] = firstValidTokenId;
        tokensToTest[1] = invalidTokenId;
        token.mint(userA, firstValidTokenId, 1);
        assertTrue(validator.isValidDiscountRegistration(userA, abi.encode(tokensToTest)));
    }

    function test_returnsTrue_whenTheUserHasMultipleTokens() public {
        uint256[] memory tokensToTest = new uint256[](2);
        tokensToTest[0] = firstValidTokenId;
        tokensToTest[1] = secondValidTokenId;
        token.mint(userA, firstValidTokenId, 1);
        token.mint(userA, secondValidTokenId, 1);
        assertTrue(validator.isValidDiscountRegistration(userA, abi.encode(tokensToTest)));
    }

    function test_returnsFalse_whenTheUserHasNoToken() public view {
        uint256[] memory tokensToTest = new uint256[](1);
        tokensToTest[0] = firstValidTokenId;
        assertFalse(validator.isValidDiscountRegistration(userA, abi.encode(tokensToTest)));
    }

    function test_returnsFalse_whenAnotherUserHasAToken() public {
        uint256[] memory tokensToTest = new uint256[](1);
        tokensToTest[0] = firstValidTokenId;
        token.mint(userB, firstValidTokenId, 1);
        assertFalse(validator.isValidDiscountRegistration(userA, abi.encode(tokensToTest)));
    }

    function test_returnsFalse_whenTheUserHasAnInvalidToken() public {
        uint256[] memory tokensToTest = new uint256[](3);
        tokensToTest[0] = firstValidTokenId;
        tokensToTest[1] = secondValidTokenId;
        tokensToTest[2] = invalidTokenId;
        token.mint(userA, invalidTokenId, 1);
        assertFalse(validator.isValidDiscountRegistration(userA, abi.encode(tokensToTest)));
    }

    function test_returnsFalseWhenTheUserHasTokenButProvidesWrongList() public {
        uint256[] memory tokensToTest = new uint256[](1);
        tokensToTest[0] = secondValidTokenId;
        token.mint(userA, firstValidTokenId, 1);
        assertFalse(validator.isValidDiscountRegistration(userA, abi.encode(tokensToTest)));
    }

    function test_returnsFalseWhenUserProvidesEmptyList() public {
        uint256[] memory tokensToTest = new uint256[](0);
        token.mint(userA, firstValidTokenId, 1);
        assertFalse(validator.isValidDiscountRegistration(userA, abi.encode(tokensToTest)));
    }
}
