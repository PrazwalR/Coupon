// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {SD59x18, sd} from "@prb/math/SD59x18.sol";

library FixedPointMath {
    uint256 internal constant WAD = 1e18;

    error DivByZero();
    error NotPositive();

    function wmul(uint256 a, uint256 b) internal pure returns (uint256) {
        return (a * b) / WAD;
    }

    function wdiv(uint256 a, uint256 b) internal pure returns (uint256) {
        if (b == 0) revert DivByZero();
        return (a * WAD) / b;
    }

    function lnWad(uint256 x) internal pure returns (int256) {
        if (x == 0) revert NotPositive();
        return SD59x18.unwrap(sd(int256(x)).ln());
    }

    function abs(int256 x) internal pure returns (uint256) {
        return x >= 0 ? uint256(x) : uint256(-x);
    }
}
