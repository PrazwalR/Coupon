// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {YieldCurve} from "../src/loans/YieldCurve.sol";

contract YieldCurveTest is Test {
    YieldCurve curve;

    function setUp() public {
        YieldCurve.CurvePoint[] memory pts = new YieldCurve.CurvePoint[](3);
        pts[0] = YieldCurve.CurvePoint(30 days, 0.06e18);
        pts[1] = YieldCurve.CurvePoint(365 days, 0.07e18);
        pts[2] = YieldCurve.CurvePoint(730 days, 0.08e18);
        curve = new YieldCurve(pts);
    }

    function test_exact_points() public view {
        assertEq(curve.rateForTenor(365 days), 0.07e18);
        assertEq(curve.rateForTenor(730 days), 0.08e18);
    }

    function test_clamp_below_and_above() public view {
        assertEq(curve.rateForTenor(1 days), 0.06e18);
        assertEq(curve.rateForTenor(3650 days), 0.08e18);
    }

    function test_interpolation_midpoint() public view {
        uint256 mid = curve.rateForTenor((365 days + 730 days) / 2);
        assertApproxEqAbs(mid, 0.075e18, 1e15);
    }

    function test_unsorted_constructor_reverts() public {
        YieldCurve.CurvePoint[] memory pts = new YieldCurve.CurvePoint[](2);
        pts[0] = YieldCurve.CurvePoint(730 days, 0.08e18);
        pts[1] = YieldCurve.CurvePoint(365 days, 0.07e18);
        vm.expectRevert(YieldCurve.Unsorted.selector);
        new YieldCurve(pts);
    }

    function test_setPoint_gov_only() public {
        vm.prank(address(0xdead));
        vm.expectRevert(YieldCurve.NotGovernance.selector);
        curve.setPoint(0, 0.05e18);
    }
}
