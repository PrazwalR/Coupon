// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {FixedPointMath} from "./FixedPointMath.sol";

library LogitCurve {
    uint256 internal constant WAD = 1e18;
    uint256 internal constant EPS = 1e12;

    error NoLiquidity();

    function utilization(int256 exposure, uint256 liquidity) internal pure returns (uint256) {
        if (liquidity == 0) revert NoLiquidity();
        int256 half = int256(WAD) / 2;
        int256 shift = (exposure * int256(WAD)) / (2 * int256(liquidity));
        int256 p = half + shift;
        int256 lo = int256(EPS);
        int256 hi = int256(WAD - EPS);
        if (p < lo) p = lo;
        if (p > hi) p = hi;
        return uint256(p);
    }

    function logit(uint256 p) internal pure returns (int256) {
        return FixedPointMath.lnWad(p) - FixedPointMath.lnWad(WAD - p);
    }

    function scalarAt(uint256 baseScalar, uint256 tenor, uint256 ttm) internal pure returns (uint256) {
        uint256 t = ttm == 0 ? 1 : ttm;
        return (baseScalar * tenor) / t;
    }

    function _term(int256 logitVal, uint256 scalar) private pure returns (int256) {
        return (logitVal * int256(WAD)) / int256(scalar);
    }

    function midRate(
        int256 restExposure,
        int256 newExposure,
        uint256 liquidity,
        uint256 lastRate,
        uint256 scalar
    ) internal pure returns (uint256) {
        int256 anchor = int256(lastRate) - _term(logit(utilization(restExposure, liquidity)), scalar);
        int256 mid = anchor + _term(logit(utilization(newExposure, liquidity)), scalar);
        return mid < 0 ? 0 : uint256(mid);
    }
}
