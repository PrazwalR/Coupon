// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {YieldCurve} from "./YieldCurve.sol";
import {SwapMarket} from "../swap/SwapMarket.sol";
import {MarginEngine} from "../swap/MarginEngine.sol";
import {SwapMath} from "../libraries/SwapMath.sol";

contract LoanOriginator is ReentrancyGuard {
    using SafeERC20 for IERC20;

    YieldCurve public immutable curve;
    SwapMarket public immutable swapMarket;
    MarginEngine public immutable margin;
    IERC20 public immutable asset;
    address public immutable governance;

    uint256 public creditSpread = 0.02e18;
    uint256 public totalCollateralHeld;

    struct Loan {
        address borrower;
        uint256 principal;
        uint256 fixedRate;
        uint256 startTime;
        uint256 maturity;
        uint256 hedgeSwapId;
        uint256 collateral;
        bool repaid;
    }

    mapping(address => uint256) public deposits;
    mapping(uint256 => Loan) public loans;
    uint256 public nextLoanId;

    error NotGovernance();
    error InsufficientCapital();
    error AlreadyRepaid();
    error NotBorrower();

    event Funded(address indexed lender, uint256 amount);
    event Withdrawn(address indexed lender, uint256 amount);
    event LoanOriginated(uint256 indexed id, address indexed borrower, uint256 principal, uint256 fixedRate, uint256 maturity);
    event LoanRepaid(uint256 indexed id, uint256 total, int256 hedgePnl);

    constructor(address _curve, address _swapMarket, address _asset) {
        governance = msg.sender;
        curve = YieldCurve(_curve);
        swapMarket = SwapMarket(_swapMarket);
        margin = SwapMarket(_swapMarket).margin();
        asset = IERC20(_asset);
        asset.forceApprove(address(margin), type(uint256).max);
    }

    modifier onlyGovernance() {
        if (msg.sender != governance) revert NotGovernance();
        _;
    }

    function setCreditSpread(uint256 bps) external onlyGovernance {
        creditSpread = bps;
    }

    function lendable() public view returns (uint256) {
        return asset.balanceOf(address(this)) - totalCollateralHeld;
    }

    function fund(uint256 amount) external nonReentrant {
        asset.safeTransferFrom(msg.sender, address(this), amount);
        deposits[msg.sender] += amount;
        emit Funded(msg.sender, amount);
    }

    function withdraw(uint256 amount) external nonReentrant {
        deposits[msg.sender] -= amount;
        if (amount > lendable()) revert InsufficientCapital();
        asset.safeTransfer(msg.sender, amount);
        emit Withdrawn(msg.sender, amount);
    }

    function quoteRate(uint256 duration) public view returns (uint256) {
        return curve.rateForTenor(duration) + creditSpread;
    }

    function originate(uint256 principal, uint256 duration, uint256 collateralAmount, uint256 hedgeMargin)
        external
        nonReentrant
        returns (uint256 loanId)
    {
        if (lendable() < principal + hedgeMargin) revert InsufficientCapital();
        uint256 borrowerRate = quoteRate(duration);

        asset.safeTransferFrom(msg.sender, address(this), collateralAmount);
        totalCollateralHeld += collateralAmount;

        uint256 swapId = swapMarket.openSwap(SwapMarket.Side.PAY_FIXED, principal, hedgeMargin);

        asset.safeTransfer(msg.sender, principal);

        loanId = nextLoanId++;
        loans[loanId] = Loan({
            borrower: msg.sender,
            principal: principal,
            fixedRate: borrowerRate,
            startTime: block.timestamp,
            maturity: block.timestamp + duration,
            hedgeSwapId: swapId,
            collateral: collateralAmount,
            repaid: false
        });

        emit LoanOriginated(loanId, msg.sender, principal, borrowerRate, block.timestamp + duration);
    }

    function accruedInterest(uint256 loanId) public view returns (uint256) {
        Loan memory loan = loans[loanId];
        uint256 elapsed = block.timestamp - loan.startTime;
        uint256 accrual = SwapMath.fixedAccrual(loan.fixedRate, elapsed);
        return (loan.principal * accrual) / 1e18;
    }

    function repay(uint256 loanId) external nonReentrant {
        Loan storage loan = loans[loanId];
        if (loan.repaid) revert AlreadyRepaid();
        if (msg.sender != loan.borrower) revert NotBorrower();

        uint256 total = loan.principal + accruedInterest(loanId);
        asset.safeTransferFrom(msg.sender, address(this), total);

        uint256 balBefore = asset.balanceOf(address(this));
        swapMarket.settle(loan.hedgeSwapId);
        int256 hedgePnl = int256(asset.balanceOf(address(this))) - int256(balBefore);

        totalCollateralHeld -= loan.collateral;
        asset.safeTransfer(loan.borrower, loan.collateral);

        loan.repaid = true;
        emit LoanRepaid(loanId, total, hedgePnl);
    }
}
