// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, stdError} from "forge-std/Test.sol";
import {RateOracle} from "../../src/oracle/RateOracle.sol";
import {MarketFactory} from "../../src/swap/MarketFactory.sol";
import {SwapMarket} from "../../src/swap/SwapMarket.sol";
import {MarginEngine} from "../../src/swap/MarginEngine.sol";
import {MarketParams} from "../../src/interfaces/IMarketParams.sol";
import {YieldCurve} from "../../src/loans/YieldCurve.sol";
import {LoanOriginator} from "../../src/loans/LoanOriginator.sol";
import {MockERC20} from "../mocks/MockERC20.sol";

contract LoanEdgeTest is Test {
    MockERC20 token;
    RateOracle oracle;
    SwapMarket market;
    MarginEngine margin;
    YieldCurve curve;
    LoanOriginator originator;

    address lp = address(0x11);
    address lender = address(0x22);
    address borrower = address(0xB0B);
    address stranger = address(0x99);

    uint256 constant TENOR = 730 days;
    uint256 constant P = 100_000e18;

    function setUp() public {
        vm.warp(1_000_000);
        token = new MockERC20();
        oracle = new RateOracle(address(this), 800 days);
        MarketFactory factory = new MarketFactory();
        MarketParams memory p = MarketParams({
            rateOracle: address(oracle),
            asset: address(token),
            underlyingRate: address(token),
            tenor: TENOR,
            initialMarginBps: 1000,
            maintenanceMarginBps: 500,
            initialFixedRate: 0.07e18,
            baseScalar: 100e18,
            liquidityFeeBps: 10
        });
        market = SwapMarket(factory.createMarket(p));
        margin = market.margin();

        YieldCurve.CurvePoint[] memory pts = new YieldCurve.CurvePoint[](2);
        pts[0] = YieldCurve.CurvePoint(365 days, 0.07e18);
        pts[1] = YieldCurve.CurvePoint(730 days, 0.075e18);
        curve = new YieldCurve(pts);
        originator = new LoanOriginator(address(curve), address(market), address(token));

        token.mint(lp, 1_000_000e18);
        token.mint(lender, 300_000e18);
        token.mint(borrower, 300_000e18);
        vm.prank(lp);
        token.approve(address(margin), type(uint256).max);
        vm.prank(lender);
        token.approve(address(originator), type(uint256).max);
        vm.prank(borrower);
        token.approve(address(originator), type(uint256).max);

        _publish(0.07e18);
        vm.prank(lp);
        market.provideLiquidity(500_000e18);
        vm.prank(lender);
        originator.fund(200_000e18);
    }

    function _publish(uint256 rate) internal {
        oracle.updateIndex(address(token), rate);
    }

    function _originate() internal returns (uint256) {
        vm.prank(borrower);
        return originator.originate(P, TENOR, 20_000e18, 10_000e18);
    }

    function test_withdraw_more_than_deposit_underflows() public {
        vm.prank(lender);
        vm.expectRevert(stdError.arithmeticError);
        originator.withdraw(200_001e18);
    }

    function test_withdraw_more_than_lendable_reverts() public {
        _originate();
        vm.prank(lender);
        vm.expectRevert(LoanOriginator.InsufficientCapital.selector);
        originator.withdraw(200_000e18);
    }

    function test_originate_exceeding_capital_reverts() public {
        vm.prank(borrower);
        vm.expectRevert(LoanOriginator.InsufficientCapital.selector);
        originator.originate(300_000e18, TENOR, 20_000e18, 30_000e18);
    }

    function test_originate_insufficient_hedge_margin_reverts() public {
        vm.prank(borrower);
        vm.expectRevert(SwapMarket.InsufficientMargin.selector);
        originator.originate(P, TENOR, 20_000e18, 5_000e18);
    }

    function test_repay_by_non_borrower_reverts() public {
        uint256 id = _originate();
        vm.warp(block.timestamp + TENOR);
        _publish(0.07e18);
        vm.prank(stranger);
        vm.expectRevert(LoanOriginator.NotBorrower.selector);
        originator.repay(id);
    }

    function test_repay_twice_reverts() public {
        uint256 id = _originate();
        vm.warp(block.timestamp + TENOR);
        _publish(0.07e18);
        vm.prank(borrower);
        originator.repay(id);
        vm.prank(borrower);
        vm.expectRevert(LoanOriginator.AlreadyRepaid.selector);
        originator.repay(id);
    }

    function test_early_repay_leaves_hedge_open() public {
        uint256 id = _originate();
        (,,,,, uint256 hedgeId,,) = originator.loans(id);

        vm.warp(block.timestamp + TENOR / 2);
        _publish(0.07e18);
        vm.prank(borrower);
        originator.repay(id);

        (,,,,,,, bool repaid) = originator.loans(id);
        assertTrue(repaid);
        assertEq(originator.totalCollateralHeld(), 0);

        (,,,,,,,, bool hedgeSettled) = market.positions(hedgeId);
        assertFalse(hedgeSettled);

        vm.warp(block.timestamp + TENOR);
        _publish(0.07e18);
        market.settle(hedgeId);
        (,,,,,,,, bool afterSettle) = market.positions(hedgeId);
        assertTrue(afterSettle);
    }

    function test_set_credit_spread_gov_only() public {
        vm.prank(stranger);
        vm.expectRevert(LoanOriginator.NotGovernance.selector);
        originator.setCreditSpread(0.05e18);

        originator.setCreditSpread(0.05e18);
        assertEq(originator.quoteRate(TENOR), 0.075e18 + 0.05e18);
    }

    function test_accrued_interest_grows() public {
        uint256 id = _originate();
        vm.warp(block.timestamp + 100 days);
        uint256 i1 = originator.accruedInterest(id);
        vm.warp(block.timestamp + 100 days);
        uint256 i2 = originator.accruedInterest(id);
        assertGt(i2, i1);
        assertGt(i1, 0);
    }
}
