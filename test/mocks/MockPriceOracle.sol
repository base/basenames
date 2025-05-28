// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {IPriceOracle} from "src/L2/interface/IPriceOracle.sol";
import {GRACE_PERIOD} from "src/util/Constants.sol";

contract MockPriceOracle is IPriceOracle {
    uint256 public constant DEFAULT_BASE_WEI = 0.1 ether;
    uint256 public constant DEFAULT_PREMIUM_WEI = 0;
    uint256 public constant DEFAULT_INCLUDED_PREMIUM = 0.2 ether;

    IPriceOracle.Price public defaultPrice = IPriceOracle.Price({base: DEFAULT_BASE_WEI, premium: DEFAULT_PREMIUM_WEI});

    mapping(string => IPriceOracle.Price) prices;

    function setPrice(string calldata name, IPriceOracle.Price calldata priceData) external {
        prices[name] = priceData;
    }

    function price(string calldata name, uint256 expires, uint256 duration)
        external
        view
        returns (IPriceOracle.Price memory)
    {
        if (prices[name].base > 0) return prices[name];
        if (
            (expires == block.timestamp + duration + GRACE_PERIOD) || (expires == block.timestamp + duration)
                || expires == 0
        ) {
            return defaultPrice;
        }
        return IPriceOracle.Price({base: DEFAULT_BASE_WEI, premium: DEFAULT_INCLUDED_PREMIUM});
    }
}
