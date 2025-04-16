//SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {Ownable} from "solady/auth/Ownable.sol";

import {IDiscountValidator} from "src/L2/interface/IDiscountValidator.sol";

/// @title Discount Validator for: Talent Protocol Builder Score
///
/// @notice Enables discounts for users who have minted their Talent Protocol Builder Score .
///         Discounts are granted based on the claimer having some score higher than this contract's `threshold`.
///
/// @author Coinbase (https://github.com/base-org/usernames)
contract TalentProtocolDiscountValidator is IDiscountValidator, Ownable {
    /// @notice Thrown when setting a critical address to the zero-address.
    error NoZeroAddress();

    /// @notice Emitted when the threshold is updated by the `owner`.
    event ThresholdUpdated(uint256 newThreshold);

    /// @notice Interface with the Talent Protocol `PassportBuilderScore` contract.
    TalentProtocol immutable talentProtocol;

    /// @notice The score threshold for qualifying for a discount.
    uint256 public threshold;

    /// @notice constructor
    ///
    /// @param owner_ The `Ownable` contract `owner`.
    /// @param talentProtocol_ The address of the Talent Protocol PassportBuilderScore contract.
    /// @param threshold_ The score required to qualify for a discount.
    constructor(address owner_, address talentProtocol_, uint256 threshold_) {
        if (owner_ == address(0)) revert NoZeroAddress();
        if (talentProtocol_ == address(0)) revert NoZeroAddress();
        talentProtocol = TalentProtocol(talentProtocol_);
        threshold = threshold_;
        _initializeOwner(owner_);
    }

    /// @notice Allows the `owner` to set the qualifying threshold.
    ///
    /// @param threshold_ The new discount-qualifying threshold.
    function setThreshold(uint256 threshold_) external onlyOwner {
        threshold = threshold_;
        emit ThresholdUpdated(threshold_);
    }

    /// @notice Required implementation for compatibility with IDiscountValidator.
    ///
    /// @dev No additional data is required for validating this discount.
    ///     NOTE: The call to `getScoreByAddress` can revert. This case should be handled gracefully by integrators.
    ///
    /// @param claimer the discount claimer's address.
    ///
    /// @return `true` if the validation data provided is determined to be valid for the specified claimer, else `false`.
    function isValidDiscountRegistration(address claimer, bytes calldata) external view returns (bool) {
        return (talentProtocol.getScoreByAddress(claimer) >= threshold);
    }
}

/// @notice Lightweight interface for the PassportBuilderScore.sol contract.
///         https://basescan.org/address/0xBBFeDA7c4d8d9Df752542b03CdD715F790B32D0B#readContract
interface TalentProtocol {
    /// @notice Gets the score of a given address.
    ///
    /// @param wallet The address to get the score for.
    ///
    /// @return The score of the given address.
    function getScoreByAddress(address wallet) external view returns (uint256);
}
