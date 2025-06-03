// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

interface IRegistrarController {
    /// @notice Getter method for checking whether an address has registered with a discount.
    ///
    /// @param registrant The address of the registrant.
    ///
    /// @return hasRegisteredWithDiscount Returns `true` if the registrant has previously claimed a discount, else `false`.
    function discountedRegistrants(address registrant) external returns (bool);

    /// @notice Checks whether any of the provided addresses have registered with a discount.
    ///
    /// @param addresses The array of addresses to check for discount registration.
    ///
    /// @return `true` if any of the addresses have already registered with a discount, else `false`.
    function hasRegisteredWithDiscount(address[] memory addresses) external view returns (bool);
}
