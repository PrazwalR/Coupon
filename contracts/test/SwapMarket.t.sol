// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {RateOracle} from "../src/oracle/RateOracle.sol";
import {MarketFactory} from "../src/swap/MarketFactory.sol";
import {SwapMarket} from "../src/swap/SwapMarket.sol";
import {MarginEngine} from "../src/swap/MarginEngine.sol";
import {MarketParams} from "../src/interfaces/IMarketParams.sol";
import {MockERC20} from "./mocks/MockERC20.sol";

contract SwapMarketTest is Test {
    MockERC20 token;
    RateOracle oracle;
    MarketFactory factory;
    SwapMarket market;
    MarginEngine margin;

    address lp = address(0x11);
    address alice = address(0xA11CE);
    address keeper = address(0x22);

    uint256 constant TENOR = 730 days;
    uint256 constant NOTIONAL = 1_000e18;
    uint256 constant FIXED = 0.07e18;

    function setUp() public {
        vm.warp(1_000_000);
        token = new MockERC20();
        oracle = new RateOracle(address(this), 800 days);

        factory = new MarketFactory();
        MarketParams memory p = MarketParams({
            rateOracle: address(oracle),
            asset: address(token),
            underlyingRate: address(token),
            tenor: TENOR,
            initialMarginBps: 1000,
            maintenanceMarginBps: 500,
            initialFixedRate: FIXED,
            baseScalar: 100e18,
            liquidityFeeBps: 10
        });
        market = SwapMarket(factory.createMarket(p));
        margin = market.margin();

        token.mint(lp, 1_000_000e18);
        token.mint(alice, 1_000e18);
        vm.prank(lp);
        token.approve(address(margin), type(uint256).max);
        vm.prank(alice);
        token.approve(address(margin), type(uint256).max);

        _publish(0.10e18);
        vm.prank(lp);
        market.provideLiquidity(500_000e18);
    }

    function _publish(uint256 rate) internal {
        oracle.updateIndex(address(token), rate);
    }

    function test_factory_registers_market() public view {
        assertEq(factory.marketCount(), 1);
        assertEq(market.tenor(), TENOR);
    }

    function test_open_requires_initial_margin() public {
        vm.prank(alice);
        vm.expectRevert(SwapMarket.InsufficientMargin.selector);
        market.openSwap(SwapMarket.Side.PAY_FIXED, NOTIONAL, 99e18);
    }

    function test_settle_before_maturity_reverts() public {
        vm.prank(alice);
        uint256 id = market.openSwap(SwapMarket.Side.PAY_FIXED, NOTIONAL, 100e18);
        vm.expectRevert(SwapMarket.NotMatured.selector);
        market.settle(id);
    }

    function test_hedge_payfixed_gains_when_floating_rises() public {
        vm.prank(alice);
        uint256 id = market.openSwap(SwapMarket.Side.PAY_FIXED, NOTIONAL, 100e18);

        vm.warp(block.timestamp + TENOR);
        _publish(0.10e18);

        int256 pnl = market.currentPnl(id);
        assertGt(pnl, 55e18);
        assertLt(pnl, 65e18);

        uint256 before = token.balanceOf(alice);
        market.settle(id);
        assertEq(token.balanceOf(alice), before + 100e18 + uint256(pnl));
    }

    function test_receivefixed_is_mirror_loss() public {
        vm.prank(alice);
        uint256 id = market.openSwap(SwapMarket.Side.RECEIVE_FIXED, NOTIONAL, 100e18);

        vm.warp(block.timestamp + TENOR);
        _publish(0.10e18);

        assertLt(market.currentPnl(id), 0);
    }

    function test_liquidate_underwater_payfixed() public {
        vm.prank(alice);
        uint256 id = market.openSwap(SwapMarket.Side.PAY_FIXED, NOTIONAL, 100e18);

        vm.warp(block.timestamp + 1);
        _publish(0.01e18);
        vm.warp(block.timestamp + 365 days);
        _publish(0.01e18);

        int256 pnl = market.currentPnl(id);
        assertLt(pnl, -50e18);

        vm.prank(keeper);
        market.liquidate(id);
        assertGt(token.balanceOf(keeper), 0);
    }
}
