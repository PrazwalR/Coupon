// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {RateAMM} from "../src/swap/RateAMM.sol";
import {LogitCurve} from "../src/libraries/LogitCurve.sol";

contract RateAMMTest is Test {
    RateAMM amm;
    uint256 constant TENOR = 730 days;
    uint256 constant RATE0 = 0.07e18;
    uint256 constant FEE_BPS = 10;

    function setUp() public {
        vm.warp(1_000_000);
        amm = new RateAMM(address(0xA), TENOR, RATE0, 100e18, FEE_BPS);
        amm.setLiquidity(1_000e18);
    }

    function test_quote_reverts_without_liquidity() public {
        RateAMM fresh = new RateAMM(address(0xA), TENOR, RATE0, 100e18, FEE_BPS);
        vm.expectRevert(LogitCurve.NoLiquidity.selector);
        fresh.quoteFixedRate(true, 100e18);
    }

    function test_payfixed_costs_more_than_receivefixed() public view {
        assertGt(amm.quoteFixedRate(true, 100e18), amm.quoteFixedRate(false, 100e18));
    }

    function test_larger_notional_more_slippage() public view {
        assertGt(amm.quoteFixedRate(true, 300e18), amm.quoteFixedRate(true, 100e18));
    }

    function test_quote_zero_notional_is_rate_plus_fee() public view {
        uint256 expected = RATE0 + (RATE0 * FEE_BPS) / 10_000;
        assertEq(amm.quoteFixedRate(true, 0), expected);
    }

    function test_onOpen_shifts_exposure_and_rate() public {
        amm.onOpen(true, 200e18);
        assertEq(amm.netFixedExposure(), 200e18);
        assertGt(amm.lastImpliedRate(), RATE0);
        assertGt(amm.quoteFixedRate(true, 0), RATE0 + (RATE0 * FEE_BPS) / 10_000);
    }

    function test_rate_time_invariant_at_rest() public {
        amm.onOpen(true, 200e18);
        uint256 restQuote = amm.quoteFixedRate(true, 0);
        vm.warp(block.timestamp + TENOR - 1 days);
        assertEq(amm.quoteFixedRate(true, 0), restQuote);
    }

    function test_open_then_close_restores_exposure() public {
        amm.onOpen(true, 200e18);
        amm.onClose(true, 200e18);
        assertEq(amm.netFixedExposure(), 0);
    }
}
