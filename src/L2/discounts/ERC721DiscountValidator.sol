//SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

import {DiscountValidator} from "./DiscountValidator.sol";

/// @title Discount Validator for: ERC721 NFTs
///
/// @notice Implements an NFT ownership validator for a ERC721 `token` contract.
///         This discount validator should only be used for "soul-bound" tokens.
///
/// @author Coinbase (https://github.com/base-org/usernames)
contract ERC721DiscountValidator is DiscountValidator {
    /// @notice The ERC721 token contract to validate against.
    IERC721 immutable token;

    /// @notice ERC721 Discount Validator constructor.
    ///
    /// @param tokenAddress The address of the token contract.
    constructor(address tokenAddress) {
        token = IERC721(tokenAddress);
    }

    /// @notice Required implementation for compatibility with IDiscountValidator.
    ///
    /// @dev No additional data is necessary to complete this validation. This validator checks that `claimer` has a nonzero
    ///     `balanceOf` the stored `token` ERC721 contract.
    ///
    /// @param claimer the discount claimer's address.
    ///
    /// @return `true` if the validation data provided is determined to be valid for the specified claimer, else `false`.
    function isValidDiscountRegistration(address claimer, bytes calldata) public view override returns (bool) {
        return (token.balanceOf(claimer) > 0);
    }
}
