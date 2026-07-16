// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IRateOracle} from "../interfaces/IRateOracle.sol";
import {MarketParams} from "../interfaces/IMarketParams.sol";
import {RateAMM} from "./RateAMM.sol";
import {MarginEngine} from "./MarginEngine.sol";
import {SwapMath} from "../libraries/SwapMath.sol";

contract SwapMarket is ReentrancyGuard {
    enum Side {
        PAY_FIXED,
        RECEIVE_FIXED
    }

    struct Position {
        address owner;
        Side side;
        uint256 notional;
        uint256 fixedRate;
        uint256 accumulatorAtOpen;
        uint256 margin;
        uint256 openedAt;
        uint256 maturity;
        bool settled;
    }

    IRateOracle public immutable oracle;
    RateAMM public immutable amm;
    MarginEngine public immutable margin;
    address public immutable asset;
    address public immutable underlyingRate;
    uint256 public immutable tenor;
    uint256 public immutable initialMarginBps;

    mapping(uint256 => Position) public positions;
    uint256 public nextPositionId;

    error InsufficientMargin();
    error AlreadySettled();
    error NotMatured();
    error NotOpen();

    event LiquidityProvided(address indexed lp, uint256 amount, uint256 totalLiquidity);
    event SwapOpened(uint256 indexed id, address indexed owner, Side side, uint256 notional, uint256 fixedRate);
    event SwapSettled(uint256 indexed id, int256 pnl);
    event SwapLiquidated(uint256 indexed id, address indexed liquidator, int256 pnl);

    constructor(MarketParams memory p) {
        oracle = IRateOracle(p.rateOracle);
        asset = p.asset;
        underlyingRate = p.underlyingRate;
        tenor = p.tenor;
        initialMarginBps = p.initialMarginBps;
        amm = new RateAMM(p.underlyingRate, p.tenor, p.initialFixedRate, p.baseScalar, p.liquidityFeeBps);
        margin = new MarginEngine(p.asset, p.maintenanceMarginBps);
    }

    function provideLiquidity(uint256 amount) external nonReentrant {
        margin.fundPool(msg.sender, amount);
        uint256 total = amm.totalLiquidity() + amount;
        amm.setLiquidity(total);
        emit LiquidityProvided(msg.sender, amount, total);
    }

    function openSwap(Side side, uint256 notional, uint256 marginAmount)
        external
        nonReentrant
        returns (uint256 id)
    {
        if (marginAmount < SwapMath.requiredMargin(notional, initialMarginBps)) {
            revert InsufficientMargin();
        }
        bool payFixed = side == Side.PAY_FIXED;
        uint256 fixedRate = amm.quoteFixedRate(payFixed, notional);

        margin.deposit(msg.sender, marginAmount);
        uint256 accNow = oracle.currentAccumulator(underlyingRate);

        id = nextPositionId++;
        positions[id] = Position({
            owner: msg.sender,
            side: side,
            notional: notional,
            fixedRate: fixedRate,
            accumulatorAtOpen: accNow,
            margin: marginAmount,
            openedAt: block.timestamp,
            maturity: block.timestamp + tenor,
            settled: false
        });

        amm.onOpen(payFixed, notional);
        emit SwapOpened(id, msg.sender, side, notional, fixedRate);
    }

    function _pnl(Position memory pos) internal view returns (int256) {
        uint256 floatingReturn = oracle.floatingReturn(underlyingRate, pos.accumulatorAtOpen);
        uint256 elapsed = block.timestamp - pos.openedAt;
        uint256 fixedAccrued = SwapMath.fixedAccrual(pos.fixedRate, elapsed);
        return SwapMath.pnl(pos.side == Side.PAY_FIXED, floatingReturn, fixedAccrued, pos.notional);
    }

    function currentPnl(uint256 id) external view returns (int256) {
        return _pnl(positions[id]);
    }

    function settle(uint256 id) external nonReentrant {
        Position storage pos = positions[id];
        if (pos.owner == address(0)) revert NotOpen();
        if (pos.settled) revert AlreadySettled();
        if (block.timestamp < pos.maturity) revert NotMatured();

        int256 pnl = _pnl(pos);
        pos.settled = true;

        margin.settlePosition(pos.owner, pos.margin, pnl);
        amm.onClose(pos.side == Side.PAY_FIXED, pos.notional);
        emit SwapSettled(id, pnl);
    }

    function liquidate(uint256 id) external nonReentrant {
        Position storage pos = positions[id];
        if (pos.owner == address(0)) revert NotOpen();
        if (pos.settled) revert AlreadySettled();

        int256 pnl = _pnl(pos);
        pos.settled = true;

        margin.liquidate(pos.owner, msg.sender, pos.margin, pos.notional, pnl);
        amm.onClose(pos.side == Side.PAY_FIXED, pos.notional);
        emit SwapLiquidated(id, msg.sender, pnl);
    }
}
