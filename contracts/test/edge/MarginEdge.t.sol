// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {MarginEngine} from "../../src/swap/MarginEngine.sol";
import {MockERC20} from "../mocks/MockERC20.sol";

contract MarginEdgeTest is Test {
    MockERC20 token;
    MarginEngine engine;
    address user = address(0xABCD);
    address lp = address(0x11);
    address liq = address(0x22);

    function setUp() public {
        token = new MockERC20();
        engine = new MarginEngine(address(token), 500);
        token.mint(user, 1_000e18);
        token.mint(lp, 10_000e18);
        vm.prank(user);
        token.approve(address(engine), type(uint256).max);
        vm.prank(lp);
        token.approve(address(engine), type(uint256).max);
        engine.deposit(user, 100e18);
        engine.fundPool(lp, 1_000e18);
    }

    function test_liquidation_boundary_exact() public view {
        assertFalse(engine.isLiquidatable(100e18, 1_000e18, -50e18));
        assertTrue(engine.isLiquidatable(100e18, 1_000e18, -(50e18 + 1)));
    }

    function test_exact_full_loss_zero_remaining() public {
        engine.settlePosition(user, 100e18, -100e18);
        assertEq(token.balanceOf(user), 900e18);
        assertEq(engine.poolBalance(), 1_100e18);
        assertEq(token.balanceOf(address(engine)), engine.collateral(user) + engine.poolBalance());
    }

    function test_settle_profit_exceeding_pool_reverts() public {
        vm.expectRevert(MarginEngine.Insolvent.selector);
        engine.settlePosition(user, 100e18, 2_000e18);
    }

    function test_liquidate_profitable_position_reverts() public {
        vm.expectRevert(MarginEngine.NotLiquidatable.selector);
        engine.liquidate(user, liq, 100e18, 1_000e18, 10e18);
    }

    function test_settle_more_than_collateral_reverts() public {
        vm.expectRevert(MarginEngine.InsufficientCollateral.selector);
        engine.settlePosition(user, 200e18, 0);
    }

    function test_deposit_zero_is_noop() public {
        uint256 c = engine.collateral(user);
        engine.deposit(user, 0);
        assertEq(engine.collateral(user), c);
    }
}
