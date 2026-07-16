// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {LogitCurve} from "../src/libraries/LogitCurve.sol";
import {SwapMath} from "../src/libraries/SwapMath.sol";

contract LibMathTest is Test {
    uint256 constant WAD = 1e18;
    uint256 constant L = 1e18;
    uint256 constant BASE_SCALAR = 100e18;

    function test_util_balanced_is_half() public pure {
        assertEq(LogitCurve.utilization(0, L), 5e17);
    }

    function test_util_direction() public pure {
        assertGt(LogitCurve.utilization(2e17, L), 5e17);
        assertLt(LogitCurve.utilization(-2e17, L), 5e17);
    }

    function test_util_clamps() public pure {
        uint256 hi = LogitCurve.utilization(10 * int256(L), L);
        assertLt(hi, WAD);
        assertGt(hi, WAD - 1e13);
    }

    function test_logit_half_is_zero() public pure {
        assertEq(LogitCurve.logit(5e17), 0);
    }

    function test_logit_monotonic() public pure {
        assertGt(LogitCurve.logit(6e17), LogitCurve.logit(5e17));
        assertLt(LogitCurve.logit(4e17), LogitCurve.logit(5e17));
    }

    function test_midRate_persists_at_rest() public pure {
        uint256 lastRate = 0.07e18;
        uint256 scalar = LogitCurve.scalarAt(BASE_SCALAR, 730 days, 730 days);
        int256 rest = 3e17;
        uint256 mid = LogitCurve.midRate(rest, rest, L, lastRate, scalar);
        assertEq(mid, lastRate);
    }

    function test_midRate_time_invariant_at_rest() public pure {
        uint256 lastRate = 0.07e18;
        int256 rest = 3e17;
        uint256 sEarly = LogitCurve.scalarAt(BASE_SCALAR, 730 days, 730 days);
        uint256 sLate = LogitCurve.scalarAt(BASE_SCALAR, 730 days, 1 days);
        assertGt(sLate, sEarly);
        assertEq(LogitCurve.midRate(rest, rest, L, lastRate, sEarly), lastRate);
        assertEq(LogitCurve.midRate(rest, rest, L, lastRate, sLate), lastRate);
    }

    function test_midRate_payfixed_pushes_up() public pure {
        uint256 lastRate = 0.07e18;
        uint256 scalar = LogitCurve.scalarAt(BASE_SCALAR, 730 days, 730 days);
        uint256 up = LogitCurve.midRate(0, 2e17, L, lastRate, scalar);
        uint256 down = LogitCurve.midRate(0, -2e17, L, lastRate, scalar);
        assertGt(up, lastRate);
        assertLt(down, lastRate);
    }

    function test_pnl_payfixed_profits_when_rates_rise() public pure {
        int256 p = SwapMath.pnl(true, 0.1e18, 0.07e18, 1000e18);
        assertEq(p, 30e18);
        int256 r = SwapMath.pnl(false, 0.1e18, 0.07e18, 1000e18);
        assertEq(r, -30e18);
    }

    function test_fixedAccrual() public pure {
        assertEq(SwapMath.fixedAccrual(0.1e18, 365 days), 0.1e18);
        assertEq(SwapMath.fixedAccrual(0.1e18, 182.5 days), 0.05e18);
    }
}
