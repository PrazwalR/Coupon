// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {RateOracle} from "../src/oracle/RateOracle.sol";
import {MarketFactory} from "../src/swap/MarketFactory.sol";
import {SwapMarket} from "../src/swap/SwapMarket.sol";
import {MarketParams} from "../src/interfaces/IMarketParams.sol";
import {YieldCurve} from "../src/loans/YieldCurve.sol";
import {LoanOriginator} from "../src/loans/LoanOriginator.sol";
import {MockERC20} from "../test/mocks/MockERC20.sol";

contract KillerDemo is Script {
    uint256 constant TENOR = 730 days;
    uint256 constant P = 100_000e18;

    address constant ACTOR = address(0xA11CE);

    function run() external {
        vm.warp(1_000_000);
        MockERC20 token = new MockERC20();
        RateOracle oracle = new RateOracle(ACTOR, 800 days);

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
        SwapMarket market = SwapMarket(factory.createMarket(p));

        YieldCurve.CurvePoint[] memory pts = new YieldCurve.CurvePoint[](2);
        pts[0] = YieldCurve.CurvePoint(365 days, 0.07e18);
        pts[1] = YieldCurve.CurvePoint(730 days, 0.075e18);
        YieldCurve curve = new YieldCurve(pts);

        LoanOriginator originator = new LoanOriginator(address(curve), address(market), address(token));

        token.mint(ACTOR, 2_000_000e18);
        vm.startPrank(ACTOR);
        token.approve(address(market.margin()), type(uint256).max);
        token.approve(address(originator), type(uint256).max);

        oracle.updateIndex(address(token), 0.07e18);
        market.provideLiquidity(500_000e18);
        originator.fund(200_000e18);

        uint256 loanId = originator.originate(P, TENOR, 20_000e18, 10_000e18);

        vm.warp(block.timestamp + 1);
        oracle.updateIndex(address(token), 0.11e18);
        vm.warp(block.timestamp + TENOR);
        oracle.updateIndex(address(token), 0.11e18);
        vm.stopPrank();

        (,,,,, uint256 hedgeId,,) = originator.loans(loanId);
        int256 swapPnl = market.currentPnl(hedgeId);
        uint256 floatingReturn = oracle.floatingReturn(address(token), 1e18);
        uint256 marketFloating = (P * floatingReturn) / 1e18;
        uint256 loanInterest = originator.accruedInterest(loanId);

        console2.log("=== Coupon killer demo: 2yr fixed loan, rates 7%% -> 11%% ===");
        console2.log("principal (USDC)          ", P / 1e18);
        console2.log("loan fixed rate (bps)     ", originator.quoteRate(TENOR) / 1e14);
        console2.log("floating return (bps)     ", floatingReturn / 1e14);
        console2.log("loan interest earned      ", loanInterest / 1e18);
        console2.log("market floating on P      ", marketFloating / 1e18);
        console2.log("unhedged shortfall        ", (marketFloating - loanInterest) / 1e18);
        console2.logInt(swapPnl / 1e18);
        console2.log("interest + hedge          ", (loanInterest + uint256(swapPnl)) / 1e18);
        console2.log("lender made whole vs float:", loanInterest + uint256(swapPnl) >= marketFloating);
    }
}
