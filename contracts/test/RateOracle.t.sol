// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {RateOracle} from "../src/oracle/RateOracle.sol";

contract RateOracleTest is Test {
    RateOracle oracle;
    address publisher = address(0xBEEF);
    address asset = address(0xA55E7);
    uint256 constant MAX_STALE = 1 days;

    function setUp() public {
        vm.warp(1_000_000);
        oracle = new RateOracle(publisher, MAX_STALE);
    }

    function _publish(uint256 rate) internal {
        vm.prank(publisher);
        oracle.updateIndex(asset, rate);
    }

    function test_non_publisher_reverts() public {
        vm.expectRevert(RateOracle.NotPublisher.selector);
        oracle.updateIndex(asset, 0.1e18);
    }

    function test_first_accumulator_is_wad() public {
        _publish(0.1e18);
        (, uint256 acc,) = oracle.latest(asset);
        assertEq(acc, 1e18);
    }

    function test_accumulator_compounds_vs_hand_calc() public {
        _publish(0.1e18);
        vm.warp(block.timestamp + 365 days);
        _publish(0.1e18);
        (, uint256 acc1,) = oracle.latest(asset);
        assertEq(acc1, 1.1e18);
        assertEq(oracle.floatingReturn(asset, 1e18), 0.1e18);

        vm.warp(block.timestamp + 365 days);
        _publish(0.1e18);
        (, uint256 acc2,) = oracle.latest(asset);
        assertEq(acc2, 1.21e18);
        assertEq(oracle.floatingReturn(asset, 1e18), 0.21e18);
    }

    function test_half_year_accrual() public {
        _publish(0.1e18);
        vm.warp(block.timestamp + 182.5 days);
        _publish(0.1e18);
        assertEq(oracle.floatingReturn(asset, 1e18), 0.05e18);
    }

    function test_same_timestamp_update_reverts() public {
        _publish(0.1e18);
        vm.expectRevert(RateOracle.StaleUpdate.selector);
        _publish(0.1e18);
    }

    function test_stale_read_reverts() public {
        _publish(0.1e18);
        vm.warp(block.timestamp + MAX_STALE + 1);
        vm.expectRevert(RateOracle.Stale.selector);
        oracle.getRate(asset);
    }

    function test_no_data_reverts() public {
        vm.expectRevert(RateOracle.NoData.selector);
        oracle.getRate(asset);
    }

    function test_set_publisher_gov_only() public {
        vm.prank(address(0xDEAD));
        vm.expectRevert(RateOracle.NotGovernance.selector);
        oracle.setPublisher(address(0x1), true);

        oracle.setPublisher(address(0x1), true);
        vm.prank(address(0x1));
        oracle.updateIndex(asset, 0.1e18);
        (uint256 r,,) = oracle.latest(asset);
        assertEq(r, 0.1e18);
    }
}
