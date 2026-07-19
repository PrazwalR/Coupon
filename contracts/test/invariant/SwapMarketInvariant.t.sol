// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {RateOracle} from "../../src/oracle/RateOracle.sol";
import {MarketFactory} from "../../src/swap/MarketFactory.sol";
import {SwapMarket} from "../../src/swap/SwapMarket.sol";
import {MarginEngine} from "../../src/swap/MarginEngine.sol";
import {MarketParams} from "../../src/interfaces/IMarketParams.sol";
import {MockERC20} from "../mocks/MockERC20.sol";

contract SwapMarketHandler is Test {
    MockERC20 public token;
    RateOracle public oracle;
    SwapMarket public market;
    MarginEngine public margin;
    uint256[] public ids;
    uint256 public constant MINT = 1e30;

    constructor() {
        vm.warp(1_000_000);
        token = new MockERC20();
        oracle = new RateOracle(address(this), 3650 days);
        MarketFactory factory = new MarketFactory();
        MarketParams memory p = MarketParams({
            rateOracle: address(oracle),
            asset: address(token),
            underlyingRate: address(token),
            tenor: 365 days,
            initialMarginBps: 1000,
            maintenanceMarginBps: 500,
            initialFixedRate: 0.07e18,
            baseScalar: 100e18,
            liquidityFeeBps: 10
        });
        market = SwapMarket(factory.createMarket(p));
        margin = market.margin();

        token.mint(address(this), MINT);
        token.approve(address(margin), type(uint256).max);
        oracle.updateIndex(address(token), 0.07e18);
        market.provideLiquidity(1e26);
    }

    function open(uint256 sideSeed, uint256 notionalSeed) public {
        uint256 notional = bound(notionalSeed, 1e18, 1e24);
        uint256 im = (notional * 1000) / 10_000;
        if (token.balanceOf(address(this)) < im) return;
        SwapMarket.Side side =
            sideSeed % 2 == 0 ? SwapMarket.Side.PAY_FIXED : SwapMarket.Side.RECEIVE_FIXED;
        uint256 id = market.openSwap(side, notional, im);
        ids.push(id);
    }

    function advance(uint256 rateSeed, uint256 dtSeed) public {
        vm.warp(block.timestamp + bound(dtSeed, 1, 60 days));
        oracle.updateIndex(address(token), bound(rateSeed, 0, 1e18));
    }

    function settle(uint256 idxSeed) public {
        if (ids.length == 0) return;
        try market.settle(ids[idxSeed % ids.length]) {} catch {}
    }

    function liquidate(uint256 idxSeed) public {
        if (ids.length == 0) return;
        try market.liquidate(ids[idxSeed % ids.length]) {} catch {}
    }
}

contract SwapMarketInvariant is Test {
    SwapMarketHandler handler;

    function setUp() public {
        handler = new SwapMarketHandler();
        targetContract(address(handler));
    }

    function invariant_engine_solvent() public view {
        MarginEngine e = handler.margin();
        assertEq(
            handler.token().balanceOf(address(e)),
            e.collateral(address(handler)) + e.poolBalance()
        );
    }

    function invariant_total_tokens_conserved() public view {
        uint256 total = handler.token().balanceOf(address(handler))
            + handler.token().balanceOf(address(handler.margin()));
        assertEq(total, handler.MINT());
    }
}
