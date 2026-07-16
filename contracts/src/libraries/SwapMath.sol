// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

library SwapMath {
    uint256 internal constant WAD = 1e18;
    uint256 internal constant YEAR = 365 days;

    function fixedAccrual(uint256 fixedRate, uint256 elapsed) internal pure returns (uint256) {
        return (fixedRate * elapsed) / YEAR;
    }

    function pnl(bool payFixed, uint256 floatingReturn, uint256 fixedAccrued, uint256 notional)
        internal
        pure
        returns (int256)
    {
        int256 legDiff = int256(floatingReturn) - int256(fixedAccrued);
        int256 frac = payFixed ? legDiff : -legDiff;
        return (frac * int256(notional)) / int256(WAD);
    }

    function requiredMargin(uint256 notional, uint256 bps) internal pure returns (uint256) {
        return (notional * bps) / 10_000;
    }
}
