//SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {IERC1155} from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";

import {IDiscountValidator} from "src/L2/interface/IDiscountValidator.sol";

/// @title Discount Validator for: ERC1155 NFTs
///
/// @notice Implements an NFT ownership validator for a stored mapping of `approvedTokenIds` for an ERC1155
///         `token` contract.
///         IMPORTANT: This discount validator should only be used for "soul-bound" tokens.
///
/// @author Coinbase (https://github.com/base-org/usernames)
contract ERC1155DiscountValidatorV2 is IDiscountValidator {
    using Address for address;

    /// @notice The ERC1155 token contract to validate against.
    address immutable token;

    /// @notice The approved token Ids of the ERC1155 token contract.
    mapping(uint256 tokenId => bool approved) approvedTokenIds;

    /// @notice ERC1155 Discount Validator constructor.
    ///
    /// @param token_ The address of the token contract.
    /// @param tokenIds The approved token ids the token `claimer` must hold.
    constructor(address token_, uint256[] memory tokenIds) {
        token = token_;
        for (uint256 i; i < tokenIds.length; i++) {
            approvedTokenIds[tokenIds[i]] = true;
        }
    }

    /// @notice Required implementation for compatibility with IDiscountValidator.
    ///
    /// @dev Encoded array of token Ids to check, set by `abi.encode(uint256[] ids)`
    ///
    /// @param claimer the discount claimer's address.
    /// @param validationData opaque bytes for performing the validation.
    ///
    /// @return `true` if the validation data provided is determined to be valid for the specified claimer, else `false`.
    function isValidDiscountRegistration(address claimer, bytes calldata validationData)
        public
        view
        override
        returns (bool)
    {
        uint256[] memory ids = abi.decode(validationData, (uint256[]));
        for (uint256 i; i < ids.length; i++) {
            uint256 id = ids[i];
            if (approvedTokenIds[id] && _getBalance(claimer, id) > 0) {
                return true;
            }
        }
        return false;
    }

    /// @notice Helper for staticcalling getBalance to avoid reentrancy vector.
    function _getBalance(address claimer, uint256 id) internal view returns (uint256) {
        bytes memory data = abi.encodeWithSelector(IERC1155.balanceOf.selector, claimer, id);
        (bytes memory returnData) = token.functionStaticCall(data);
        return (abi.decode(returnData, (uint256)));
    }
}
