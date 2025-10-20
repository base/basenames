//SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "src/L2/discounts/DiscountValidator.sol";

contract MockDiscountValidator is DiscountValidator {
    bool returnValue = true;

    function isValidDiscountRegistration(address, bytes calldata) public view override returns (bool) {
        return returnValue;
    }

    function setReturnValue(bool value) external {
        returnValue = value;
    }
}
