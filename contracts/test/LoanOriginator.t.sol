// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {RateOracle} from "../src/oracle/RateOracle.sol";
import {MarketFactory} from "../src/swap/MarketFactory.sol";
import {SwapMarket} from "../src/swap/SwapMarket.sol";
import {MarginEngine} from "../src/swap/MarginEngine.sol";
import {MarketParams} from "../src/interfaces/IMarketParams.sol";
import {YieldCurve} from "../src/loans/YieldCurve.sol";
import {LoanOriginator} from "../src/loans/LoanOriginator.sol";
import {MockERC20} from "./mocks/MockERC20.sol";

contract LoanOriginatorTest is Test {
    MockERC20 token;
    RateOracle oracle;
    SwapMarket market;
    MarginEngine margin;
    YieldCurve curve;
    LoanOriginator originator;

    address lp = address(0x11);
    address lender = address(0x22);
    address borrower = address(0xB0B);

    uint256 constant TENOR = 730 days;
    uint256 constant P = 100_000e18;
    uint256 constant COLLATERAL = 20_000e18;
    uint256 constant HEDGE_MARGIN = 10_000e18;

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
        token.mint(borrower, 200_000e18);

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
        return originator.originate(P, TENOR, COLLATERAL, HEDGE_MARGIN);
    }

    function test_quote_rate() public view {
        assertEq(originator.quoteRate(TENOR), 0.075e18 + 0.02e18);
    }

    function test_originate_disburses_and_hedges() public {
        uint256 before = token.balanceOf(borrower);
        uint256 loanId = _originate();
        assertEq(token.balanceOf(borrower), before + P - COLLATERAL);
        (address b, uint256 principal,,,,,,) = originator.loans(loanId);
        assertEq(b, borrower);
        assertEq(principal, P);
    }

    function test_repay_returns_collateral() public {
        uint256 loanId = _originate();
        vm.warp(block.timestamp + TENOR);
        _publish(0.07e18);
        uint256 interest = originator.accruedInterest(loanId);
        uint256 before = token.balanceOf(borrower);
        vm.prank(borrower);
        originator.repay(loanId);
        (,,,,,,, bool repaid) = originator.loans(loanId);
        assertTrue(repaid);
        assertEq(token.balanceOf(borrower), before - (P + interest) + COLLATERAL);
        assertEq(originator.totalCollateralHeld(), 0);
    }

    function test_fund_and_withdraw() public {
        uint256 lend = originator.lendable();
        assertGt(lend, 0);
        vm.prank(lender);
        originator.withdraw(50_000e18);
        assertEq(originator.lendable(), lend - 50_000e18);
    }

    function test_killer_demo_lender_made_whole() public {
        uint256 loanId = _originate();

        vm.warp(block.timestamp + 1);
        _publish(0.11e18);
        vm.warp(block.timestamp + TENOR);
        _publish(0.11e18);

        (,,,,, uint256 hedgeId,,) = originator.loans(loanId);
        int256 swapPnl = market.currentPnl(hedgeId);
        assertGt(swapPnl, 0);

        uint256 floatingReturn = oracle.floatingReturn(address(token), 1e18);
        uint256 marketFloating = (P * floatingReturn) / 1e18;
        uint256 loanInterest = originator.accruedInterest(loanId);

        assertLt(loanInterest, marketFloating);
        assertGe(loanInterest + uint256(swapPnl), marketFloating);

        uint256 lendableBefore = originator.lendable();
        vm.prank(borrower);
        originator.repay(loanId);
        assertGt(originator.lendable(), lendableBefore);
    }
}
