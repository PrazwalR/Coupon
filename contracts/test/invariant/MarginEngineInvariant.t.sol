// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {MarginEngine} from "../../src/swap/MarginEngine.sol";
import {MockERC20} from "../mocks/MockERC20.sol";

contract MarginHandler is Test {
    MarginEngine public engine;
    MockERC20 public token;

    constructor() {
        token = new MockERC20();
        engine = new MarginEngine(address(token), 500);
        token.mint(address(this), 1e30);
        token.approve(address(engine), type(uint256).max);
    }

    function deposit(uint256 amt) public {
        amt = bound(amt, 0, 1e24);
        if (token.balanceOf(address(this)) < amt) return;
        engine.deposit(address(this), amt);
    }

    function fund(uint256 amt) public {
        amt = bound(amt, 0, 1e24);
        if (token.balanceOf(address(this)) < amt) return;
        engine.fundPool(address(this), amt);
    }

    function settle(uint256 marginAmt, uint256 pnlSeed) public {
        uint256 c = engine.collateral(address(this));
        if (c == 0) return;
        marginAmt = bound(marginAmt, 1, c);
        int256 lo = -int256(marginAmt);
        int256 hi = int256(engine.poolBalance());
        int256 pnl = lo + int256(bound(pnlSeed, 0, uint256(hi - lo)));
        engine.settlePosition(address(this), marginAmt, pnl);
    }

    function liquidate(uint256 marginAmt, uint256 notional) public {
        uint256 c = engine.collateral(address(this));
        if (c == 0) return;
        marginAmt = bound(marginAmt, 1, c);
        notional = bound(notional, marginAmt, 1e27);
        engine.liquidate(address(this), address(0xBEEF), marginAmt, notional, -int256(marginAmt));
    }
}

contract MarginEngineInvariant is Test {
    MarginHandler handler;

    function setUp() public {
        handler = new MarginHandler();
        targetContract(address(handler));
    }

    function invariant_value_conserved() public view {
        MarginEngine e = handler.engine();
        assertEq(
            handler.token().balanceOf(address(e)),
            e.collateral(address(handler)) + e.poolBalance()
        );
    }
}
