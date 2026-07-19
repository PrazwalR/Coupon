// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {RateOracle} from "../../src/oracle/RateOracle.sol";

contract OracleEdgeTest is Test {
    RateOracle oracle;
    address pub = address(this);
    address a = address(0xA);
    address b = address(0xB);

    function setUp() public {
        vm.warp(1_000_000);
        oracle = new RateOracle(pub, 3650 days);
    }

    function test_multi_asset_independent() public {
        oracle.updateIndex(a, 0.05e18);
        oracle.updateIndex(b, 0.20e18);
        vm.warp(block.timestamp + 365 days);
        oracle.updateIndex(a, 0.05e18);
        oracle.updateIndex(b, 0.20e18);
        assertApproxEqAbs(oracle.floatingReturn(a, 1e18), 0.05e18, 1);
        assertApproxEqAbs(oracle.floatingReturn(b, 1e18), 0.20e18, 1);
    }

    function test_zero_rate_accrues_nothing() public {
        oracle.updateIndex(a, 0);
        vm.warp(block.timestamp + 365 days);
        oracle.updateIndex(a, 0);
        assertEq(oracle.floatingReturn(a, 1e18), 0);
    }

    function test_long_horizon_no_overflow() public {
        oracle.updateIndex(a, 0.20e18);
        for (uint256 i = 0; i < 50; i++) {
            vm.warp(block.timestamp + 365 days);
            oracle.updateIndex(a, 0.20e18);
        }
        (, uint256 acc,) = oracle.latest(a);
        assertGt(acc, 1e18);
        uint256 fr = oracle.floatingReturn(a, 1e18);
        assertGt(fr, 9e18);
    }

    function test_floatingReturn_accStart_zero_reverts() public {
        oracle.updateIndex(a, 0.05e18);
        vm.expectRevert(RateOracle.BadInput.selector);
        oracle.floatingReturn(a, 0);
    }

    function test_accumulator_never_decreases_across_rate_changes() public {
        oracle.updateIndex(a, 0.10e18);
        (, uint256 acc0,) = oracle.latest(a);
        vm.warp(block.timestamp + 10 days);
        oracle.updateIndex(a, 0);
        (, uint256 acc1,) = oracle.latest(a);
        vm.warp(block.timestamp + 10 days);
        oracle.updateIndex(a, 0.30e18);
        (, uint256 acc2,) = oracle.latest(a);
        assertGe(acc1, acc0);
        assertGe(acc2, acc1);
    }

    function test_partial_period_uses_prior_rate() public {
        oracle.updateIndex(a, 0.10e18);
        vm.warp(block.timestamp + 73 days);
        oracle.updateIndex(a, 0.99e18);
        assertApproxEqAbs(oracle.floatingReturn(a, 1e18), 0.02e18, 1e15);
    }
}
