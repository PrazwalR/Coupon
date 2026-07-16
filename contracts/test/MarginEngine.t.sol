// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {MarginEngine} from "../src/swap/MarginEngine.sol";
import {MockERC20} from "./mocks/MockERC20.sol";

contract MarginEngineTest is Test {
    MockERC20 token;
    MarginEngine engine;

    address user = address(0xABCD);
    address lp = address(0x11);
    address liquidator = address(0x22);

    function setUp() public {
        token = new MockERC20();
        engine = new MarginEngine(address(token), 500);

        token.mint(user, 1_000e18);
        token.mint(lp, 10_000e18);
        vm.prank(user);
        token.approve(address(engine), type(uint256).max);
        vm.prank(lp);
        token.approve(address(engine), type(uint256).max);
    }

    function _deposit(uint256 amt) internal {
        engine.deposit(user, amt);
    }

    function _fund(uint256 amt) internal {
        engine.fundPool(lp, amt);
    }

    function _conserved() internal view {
        assertEq(token.balanceOf(address(engine)), engine.collateral(user) + engine.poolBalance());
    }

    function test_access_control() public {
        vm.startPrank(address(0xdead));
        vm.expectRevert(MarginEngine.NotMarket.selector);
        engine.deposit(user, 1);
        vm.expectRevert(MarginEngine.NotMarket.selector);
        engine.fundPool(lp, 1);
        vm.expectRevert(MarginEngine.NotMarket.selector);
        engine.settlePosition(user, 1, 0);
        vm.expectRevert(MarginEngine.NotMarket.selector);
        engine.liquidate(user, liquidator, 1, 1, 0);
        vm.stopPrank();
    }

    function test_deposit_pulls_tokens() public {
        _deposit(100e18);
        assertEq(engine.collateral(user), 100e18);
        assertEq(token.balanceOf(user), 900e18);
    }

    function test_settle_profit_paid_from_pool() public {
        _deposit(100e18);
        _fund(1_000e18);
        engine.settlePosition(user, 100e18, 30e18);
        assertEq(token.balanceOf(user), 900e18 + 130e18);
        assertEq(engine.poolBalance(), 970e18);
        assertEq(engine.collateral(user), 0);
        _conserved();
    }

    function test_settle_loss_credits_pool() public {
        _deposit(100e18);
        _fund(1_000e18);
        engine.settlePosition(user, 100e18, -30e18);
        assertEq(token.balanceOf(user), 900e18 + 70e18);
        assertEq(engine.poolBalance(), 1_030e18);
        _conserved();
    }

    function test_settle_full_loss_zero_payout() public {
        _deposit(100e18);
        _fund(1_000e18);
        engine.settlePosition(user, 100e18, -100e18);
        assertEq(token.balanceOf(user), 900e18);
        assertEq(engine.poolBalance(), 1_100e18);
        _conserved();
    }

    function test_settle_insolvent_reverts() public {
        _deposit(100e18);
        _fund(10e18);
        vm.expectRevert(MarginEngine.Insolvent.selector);
        engine.settlePosition(user, 100e18, 30e18);
    }

    function test_isLiquidatable_threshold() public view {
        assertTrue(engine.isLiquidatable(100e18, 1_000e18, -60e18));
        assertFalse(engine.isLiquidatable(100e18, 1_000e18, -40e18));
    }

    function test_liquidate_splits_remaining() public {
        _deposit(100e18);
        _fund(1_000e18);
        engine.liquidate(user, liquidator, 100e18, 1_000e18, -60e18);
        assertEq(token.balanceOf(liquidator), 2e18);
        assertEq(token.balanceOf(user), 900e18 + 38e18);
        assertEq(engine.poolBalance(), 1_060e18);
        _conserved();
    }

    function test_liquidate_not_liquidatable_reverts() public {
        _deposit(100e18);
        _fund(1_000e18);
        vm.expectRevert(MarginEngine.NotLiquidatable.selector);
        engine.liquidate(user, liquidator, 100e18, 1_000e18, -40e18);
    }
}
