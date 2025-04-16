//SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Test} from "forge-std/Test.sol";
import {ERC1155DiscountValidatorV2} from "src/L2/discounts/ERC1155DiscountValidatorV2.sol";
import {MockERC1155} from "test/mocks/MockERC1155.sol";

contract ERC1155DiscountValidatorV2Base is Test {
    ERC1155DiscountValidatorV2 validator;
    MockERC1155 token;
    uint256 firstValidTokenId = 1;
    uint256 secondValidTokenId = 2;
    uint256 invalidTokenId = type(uint256).max;
    address userA = makeAddr("userA");
    address userB = makeAddr("userB");

    function setUp() public {
        token = new MockERC1155();
        uint256[] memory validTokens = new uint256[](2);
        validTokens[0] = firstValidTokenId;
        validTokens[1] = secondValidTokenId;
        validator = new ERC1155DiscountValidatorV2(address(token), validTokens);
    }
}
