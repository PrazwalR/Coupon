// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {SwapMath} from "../../src/libraries/SwapMath.sol";
import {LogitCurve} from "../../src/libraries/LogitCurve.sol";

contract FuzzMathTest is Test {
    function testFuzz_pnl_is_zero_sum(uint256 fr, uint256 fx, uint256 notional) public pure {
        fr = bound(fr, 0, 1e20);
        fx = bound(fx, 0, 1e20);
        notional = bound(notional, 0, 1e30);
        int256 payer = SwapMath.pnl(true, fr, fx, notional);
        int256 receiver = SwapMath.pnl(false, fr, fx, notional);
        assertEq(payer, -receiver);
    }

    function testFuzz_pnl_sign_follows_rates(uint256 fr, uint256 fx, uint256 notional) public pure {
        fr = bound(fr, 0, 1e20);
        fx = bound(fx, 0, 1e20);
        notional = bound(notional, 1, 1e30);
        int256 payer = SwapMath.pnl(true, fr, fx, notional);
        if (fr > fx) {
            assertGe(payer, 0);
        } else if (fr < fx) {
            assertLe(payer, 0);
        }
    }

    function testFuzz_logit_persists_at_rest(int256 exp, uint256 scalarSeed) public pure {
        int256 e = bound(exp, -9e17, 9e17);
        uint256 scalar = bound(scalarSeed, 1e18, 1_000e18);
        uint256 lastRate = 0.07e18;
        assertEq(LogitCurve.midRate(e, e, 1e18, lastRate, scalar), lastRate);
    }

    function testFuzz_logit_monotonic_in_exposure(int256 e1, int256 e2) public pure {
        int256 a = bound(e1, -8e17, 8e17);
        int256 b = bound(e2, -8e17, 8e17);
        vm.assume(a < b);
        uint256 r1 = LogitCurve.midRate(0, a, 1e18, 0.07e18, 100e18);
        uint256 r2 = LogitCurve.midRate(0, b, 1e18, 0.07e18, 100e18);
        assertGe(r2, r1);
    }

    function testFuzz_utilization_bounded(int256 exp, uint256 liq) public pure {
        uint256 liquidity = bound(liq, 1, 1e30);
        int256 e = bound(exp, -1e30, 1e30);
        uint256 p = LogitCurve.utilization(e, liquidity);
        assertGt(p, 0);
        assertLt(p, 1e18);
    }
}
