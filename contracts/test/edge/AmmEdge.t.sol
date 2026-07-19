// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {RateAMM} from "../../src/swap/RateAMM.sol";
import {LogitCurve} from "../../src/libraries/LogitCurve.sol";

contract AmmEdgeTest is Test {
    RateAMM amm;
    uint256 constant TENOR = 730 days;
    uint256 constant RATE0 = 0.07e18;
    uint256 constant L = 1_000e18;

    function setUp() public {
        vm.warp(1_000_000);
        amm = new RateAMM(address(0xA), TENOR, RATE0, 100e18, 10);
        amm.setLiquidity(L);
    }

    function test_logit_curve_is_real_nonlinear_and_convex() public view {
        uint256[5] memory n = [uint256(50e18), 100e18, 150e18, 200e18, 250e18];
        uint256[5] memory r;
        for (uint256 i = 0; i < 5; i++) {
            r[i] = amm.quoteFixedRate(true, n[i]);
        }
        for (uint256 i = 0; i < 4; i++) {
            assertGt(r[i + 1], r[i]);
        }
        uint256 d1 = r[1] - r[0];
        uint256 d2 = r[2] - r[1];
        uint256 d3 = r[3] - r[2];
        uint256 d4 = r[4] - r[3];
        assertGt(d2, d1);
        assertGt(d3, d2);
        assertGt(d4, d3);
    }

    function test_extreme_utilization_no_revert() public view {
        uint256 pay = amm.quoteFixedRate(true, 10 * L);
        uint256 recv = amm.quoteFixedRate(false, 10 * L);
        assertGt(pay, RATE0);
        assertLe(recv, RATE0);
    }

    function test_notional_exceeds_liquidity_clamps_finite() public view {
        uint256 moderate = amm.quoteFixedRate(true, 500e18);
        uint256 huge = amm.quoteFixedRate(true, 100 * L);
        assertGt(huge, moderate);
        assertLt(huge, 100e18);
    }

    function test_deeper_liquidity_less_slippage() public {
        uint256 shallow = amm.quoteFixedRate(true, 300e18);
        amm.setLiquidity(100_000e18);
        uint256 deep = amm.quoteFixedRate(true, 300e18);
        assertLt(deep, shallow);
        assertGt(deep, RATE0);
    }

    function test_ttm_zero_quote_works() public {
        vm.warp(amm.maturity() + 1);
        assertEq(amm.timeToMaturity(), 0);
        uint256 q = amm.quoteFixedRate(true, 100e18);
        assertGt(q, 0);
    }

    function test_sequential_trades_move_exposure_and_rate() public {
        amm.onOpen(true, 100e18);
        uint256 r1 = amm.lastImpliedRate();
        assertEq(amm.netFixedExposure(), 100e18);
        amm.onOpen(true, 100e18);
        uint256 r2 = amm.lastImpliedRate();
        assertEq(amm.netFixedExposure(), 200e18);
        assertGt(r2, r1);
        assertGt(r1, RATE0);
    }

    function test_close_reverts_exposure() public {
        amm.onOpen(true, 200e18);
        uint256 mid = amm.quoteFixedRate(true, 0);
        amm.onClose(true, 200e18);
        assertEq(amm.netFixedExposure(), 0);
        uint256 back = amm.quoteFixedRate(true, 0);
        assertLt(back, mid);
    }

    function test_receivefixed_floor_at_zero() public view {
        uint256 q = amm.quoteFixedRate(false, 100 * L);
        assertEq(q, 0);
    }

    function test_quote_without_liquidity_reverts_not_silent() public {
        RateAMM dry = new RateAMM(address(0xA), TENOR, RATE0, 100e18, 10);
        vm.expectRevert(LogitCurve.NoLiquidity.selector);
        dry.quoteFixedRate(true, 1e18);
    }
}
