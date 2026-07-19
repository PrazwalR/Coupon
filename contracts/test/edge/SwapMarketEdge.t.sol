// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {RateOracle} from "../../src/oracle/RateOracle.sol";
import {MarketFactory} from "../../src/swap/MarketFactory.sol";
import {SwapMarket} from "../../src/swap/SwapMarket.sol";
import {MarginEngine} from "../../src/swap/MarginEngine.sol";
import {MarketParams} from "../../src/interfaces/IMarketParams.sol";
import {MockERC20} from "../mocks/MockERC20.sol";

contract SwapMarketEdgeTest is Test {
    MockERC20 token;
    RateOracle oracle;
    SwapMarket market;
    MarginEngine margin;

    address lp = address(0x11);
    address alice = address(0xA11CE);
    address bob = address(0xB0B);
    address keeper = address(0x22);

    uint256 constant TENOR = 730 days;
    uint256 constant MAX_STALE = 30 days;

    function setUp() public {
        vm.warp(1_000_000);
        token = new MockERC20();
        oracle = new RateOracle(address(this), MAX_STALE);
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

        token.mint(lp, 1_000_000e18);
        token.mint(alice, 100_000e18);
        token.mint(bob, 100_000e18);
        vm.prank(lp);
        token.approve(address(margin), type(uint256).max);
        vm.prank(alice);
        token.approve(address(margin), type(uint256).max);
        vm.prank(bob);
        token.approve(address(margin), type(uint256).max);

        _publish(0.08e18);
        vm.prank(lp);
        market.provideLiquidity(500_000e18);
    }

    function _publish(uint256 rate) internal {
        oracle.updateIndex(address(token), rate);
    }

    function _open(address who, SwapMarket.Side side) internal returns (uint256 id) {
        vm.prank(who);
        id = market.openSwap(side, 1_000e18, 100e18);
    }

    function test_open_when_oracle_stale_reverts() public {
        vm.warp(block.timestamp + MAX_STALE + 1);
        vm.prank(alice);
        vm.expectRevert(RateOracle.Stale.selector);
        market.openSwap(SwapMarket.Side.PAY_FIXED, 1_000e18, 100e18);
    }

    function test_double_settle_reverts() public {
        uint256 id = _open(alice, SwapMarket.Side.PAY_FIXED);
        vm.warp(block.timestamp + TENOR);
        _publish(0.08e18);
        market.settle(id);
        vm.expectRevert(SwapMarket.AlreadySettled.selector);
        market.settle(id);
    }

    function test_settle_nonexistent_reverts() public {
        vm.expectRevert(SwapMarket.NotOpen.selector);
        market.settle(999);
    }

    function test_liquidate_healthy_reverts() public {
        uint256 id = _open(alice, SwapMarket.Side.PAY_FIXED);
        vm.warp(block.timestamp + 1);
        _publish(0.08e18);
        vm.prank(keeper);
        vm.expectRevert(MarginEngine.NotLiquidatable.selector);
        market.liquidate(id);
    }

    function test_liquidate_settled_reverts() public {
        uint256 id = _open(alice, SwapMarket.Side.PAY_FIXED);
        vm.warp(block.timestamp + TENOR);
        _publish(0.08e18);
        market.settle(id);
        vm.prank(keeper);
        vm.expectRevert(SwapMarket.AlreadySettled.selector);
        market.liquidate(id);
    }

    function test_settle_when_stale_reverts_until_publish() public {
        uint256 id = _open(alice, SwapMarket.Side.PAY_FIXED);
        vm.warp(block.timestamp + TENOR + MAX_STALE + 1);
        vm.expectRevert(RateOracle.Stale.selector);
        market.settle(id);
        _publish(0.08e18);
        market.settle(id);
        (,,,,,,,, bool settled) = market.positions(id);
        assertTrue(settled);
    }

    function test_settle_at_exact_maturity() public {
        uint256 id = _open(alice, SwapMarket.Side.PAY_FIXED);
        (,,,,,,, uint256 maturity,) = market.positions(id);
        vm.warp(maturity);
        _publish(0.08e18);
        market.settle(id);
        (,,,,,,,, bool settled) = market.positions(id);
        assertTrue(settled);
    }

    function test_open_zero_notional_settles_zero() public {
        vm.prank(alice);
        uint256 id = market.openSwap(SwapMarket.Side.PAY_FIXED, 0, 0);
        vm.warp(block.timestamp + TENOR);
        _publish(0.08e18);
        assertEq(market.currentPnl(id), 0);
        market.settle(id);
    }

    function test_two_positions_independent() public {
        uint256 idA = _open(alice, SwapMarket.Side.PAY_FIXED);
        uint256 idB = _open(bob, SwapMarket.Side.RECEIVE_FIXED);
        vm.warp(block.timestamp + TENOR);
        _publish(0.20e18);
        int256 pnlA = market.currentPnl(idA);
        int256 pnlB = market.currentPnl(idB);
        assertGt(pnlA, 0);
        assertLt(pnlB, 0);
    }
}
