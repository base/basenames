// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

/// @title Discount Validato 
///
/// @notice Discount Validator base contract which must be inherited by implementing validators.
///         The logic specific to each integration must ultimately be consumable as:
///             1. A `bool` returned from `isValidDiscountRegistration` for offchain pre-tx validation, and 
///             2. A call to `validateDiscountRegistration` which will revert if validation fails
abstract contract DiscountValidator {
    /// @notice Thrown when the specified discount's validator does not accept the discount for the sender.
    ///
    /// @param claimer The address of the claiming user. 
    /// @param data The associated `validationData`.
    error InvalidDiscount(address claimer, bytes data);

    /// @notice Required implementation for compatibility with DiscountValidator.
    ///
    /// @dev Each implementation will have unique requirements for the data necessary to perform
    ///     a meaningul validation. Implementations must describe here how to pack relevant `validationData`.
    ///     Ex: `bytes validationData = abi.encode(bytes32 key, bytes32[] proof)`
    ///
    /// @param claimer the discount claimer's address.
    /// @param validationData opaque bytes for performing the validation.
    ///
    /// @return `true` if the validation data provided is determined to be valid for the specified claimer, else `false`.
    function isValidDiscountRegistration(address claimer, bytes calldata validationData) public virtual view returns (bool);


    /// @notice Required implementation for compaibility with DiscountValidator.
    /// 
    /// @dev This method reverts with `InvalidDiscount` if called with for an invalid combination of `claimer` and `validationData`.
    ///     By default, it simply calls `isValidDiscountRegistration`. If more sophisticated state tracking is required, overwrite this
    ///     method. Overwriten methods MUST still revert with `InvalidDiscount` should the data fail the validation step. 
    ///
    /// @param claimer the discount claimer's address.
    /// @param validationData opaque bytes for performing the validation.
    function validateDiscountRegistration(address claimer, bytes calldata validationData) external virtual {
        if(!isValidDiscountRegistration(claimer, validationData)) revert InvalidDiscount(claimer, validationData);
    }
}
