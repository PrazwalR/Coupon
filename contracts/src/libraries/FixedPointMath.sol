// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {SD59x18, sd} from "@prb/math/SD59x18.sol";

library FixedPointMath {
    uint256 internal constant WAD = 1e18;

    error NotPositive();

    function lnWad(uint256 x) internal pure returns (int256) {
        if (x == 0) revert NotPositive();
        return SD59x18.unwrap(sd(int256(x)).ln());
    }
}
