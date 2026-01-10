//SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {IERC1155} from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";

import {DiscountValidator} from "./DiscountValidator.sol";

/// @title Discount Validator for: ERC1155 NFTs
///
/// @notice Implements an NFT ownership validator for a stored `tokenId` for an ERC1155 `token` contract.
///         This discount validator should only be used for "soul-bound" tokens.
///
/// @author Coinbase (https://github.com/base-org/usernames)
contract ERC1155DiscountValidator is DiscountValidator {
    /// @notice The ERC1155 token contract to validate against.
    IERC1155 immutable token;

    /// @notice The ERC1155 token ID of the relevant NFT.
    uint256 immutable tokenId;

    /// @notice ERC1155 Discount Validator constructor.
    ///
    /// @param tokenAddress The address of the token contract.
    /// @param tokenId_ The ID of the token `claimer` must hold.
    constructor(address tokenAddress, uint256 tokenId_) {
        token = IERC1155(tokenAddress);
        tokenId = tokenId_;
    }

    /// @notice Required implementation for compatibility with IDiscountValidator.
    ///
    /// @dev No additional data is necessary to complete this validation. This validator checks that `claimer` has a nonzero
    ///     `balanceOf` the stored `tokenId` for the stored `token` ERC1155 contract.
    ///
    /// @param claimer the discount claimer's address.
    ///
    /// @return `true` if the validation data provided is determined to be valid for the specified claimer, else `false`.
    function isValidDiscountRegistration(address claimer, bytes calldata) public view override returns (bool) {
        return (token.balanceOf(claimer, tokenId) > 0);
    }
}
