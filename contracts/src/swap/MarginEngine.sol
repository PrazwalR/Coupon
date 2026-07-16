// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract MarginEngine is ReentrancyGuard {
    using SafeERC20 for IERC20;

    IERC20 public immutable asset;
    address public immutable market;
    uint256 public immutable maintenanceMarginBps;

    uint256 public constant LIQUIDATION_BONUS_BPS = 500;

    mapping(address => uint256) public collateral;
    uint256 public poolBalance;

    error NotMarket();
    error Insolvent();
    error InsufficientCollateral();
    error NotLiquidatable();

    event MarginDeposited(address indexed owner, uint256 amount);
    event PoolFunded(address indexed from, uint256 amount);
    event PositionSettled(address indexed owner, uint256 postedMargin, int256 pnl, uint256 payout);
    event PositionLiquidated(address indexed owner, address indexed liquidator, uint256 bonus);

    constructor(address _asset, uint256 _maintenanceMarginBps) {
        asset = IERC20(_asset);
        market = msg.sender;
        maintenanceMarginBps = _maintenanceMarginBps;
    }

    modifier onlyMarket() {
        if (msg.sender != market) revert NotMarket();
        _;
    }

    function deposit(address from, uint256 amount) external onlyMarket nonReentrant {
        asset.safeTransferFrom(from, address(this), amount);
        collateral[from] += amount;
        emit MarginDeposited(from, amount);
    }

    function fundPool(address from, uint256 amount) external onlyMarket nonReentrant {
        asset.safeTransferFrom(from, address(this), amount);
        poolBalance += amount;
        emit PoolFunded(from, amount);
    }

    function isLiquidatable(uint256 postedMargin, uint256 notional, int256 pnl)
        public
        view
        returns (bool)
    {
        int256 equity = int256(postedMargin) + pnl;
        uint256 maintenanceReq = (notional * maintenanceMarginBps) / 10_000;
        return equity < int256(maintenanceReq);
    }

    function _applyPnl(address owner, uint256 postedMargin, int256 pnl)
        internal
        returns (uint256 remaining)
    {
        if (collateral[owner] < postedMargin) revert InsufficientCollateral();
        collateral[owner] -= postedMargin;

        if (pnl >= 0) {
            uint256 profit = uint256(pnl);
            if (poolBalance < profit) revert Insolvent();
            poolBalance -= profit;
            remaining = postedMargin + profit;
        } else {
            uint256 loss = uint256(-pnl);
            if (loss >= postedMargin) {
                poolBalance += postedMargin;
                remaining = 0;
            } else {
                poolBalance += loss;
                remaining = postedMargin - loss;
            }
        }
    }

    function settlePosition(address owner, uint256 postedMargin, int256 pnl)
        external
        onlyMarket
        nonReentrant
    {
        uint256 payout = _applyPnl(owner, postedMargin, pnl);
        if (payout > 0) asset.safeTransfer(owner, payout);
        emit PositionSettled(owner, postedMargin, pnl, payout);
    }

    function liquidate(
        address owner,
        address liquidator,
        uint256 postedMargin,
        uint256 notional,
        int256 pnl
    ) external onlyMarket nonReentrant {
        if (!isLiquidatable(postedMargin, notional, pnl)) revert NotLiquidatable();
        uint256 remaining = _applyPnl(owner, postedMargin, pnl);
        uint256 bonus = (remaining * LIQUIDATION_BONUS_BPS) / 10_000;
        if (bonus > 0) asset.safeTransfer(liquidator, bonus);
        uint256 ownerPayout = remaining - bonus;
        if (ownerPayout > 0) asset.safeTransfer(owner, ownerPayout);
        emit PositionLiquidated(owner, liquidator, bonus);
    }
}
