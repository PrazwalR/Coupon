import { parseAbi } from "viem";

export const rateOracleAbi = parseAbi([
  "function getRate(address asset) view returns (uint256)",
  "function currentAccumulator(address asset) view returns (uint256)",
  "function floatingReturn(address asset, uint256 accStart) view returns (uint256)",
  "function latest(address asset) view returns (uint256 rate, uint256 accumulator, uint256 timestamp)",
  "function updateIndex(address asset, uint256 newRate)",
  "function isPublisher(address) view returns (bool)",
]);

export const marketFactoryAbi = parseAbi([
  "struct MarketParams { address rateOracle; address asset; address underlyingRate; uint256 tenor; uint256 initialMarginBps; uint256 maintenanceMarginBps; uint256 initialFixedRate; uint256 baseScalar; uint256 liquidityFeeBps; }",
  "function createMarket(MarketParams params) returns (address)",
  "function marketId(MarketParams params) pure returns (bytes32)",
  "function markets(bytes32) view returns (address)",
  "function allMarkets(uint256) view returns (address)",
  "function marketCount() view returns (uint256)",
]);

export const swapMarketAbi = parseAbi([
  "function openSwap(uint8 side, uint256 notional, uint256 marginAmount) returns (uint256)",
  "function settle(uint256 id)",
  "function liquidate(uint256 id)",
  "function provideLiquidity(uint256 amount)",
  "function currentPnl(uint256 id) view returns (int256)",
  "function positions(uint256) view returns (address owner, uint8 side, uint256 notional, uint256 fixedRate, uint256 accumulatorAtOpen, uint256 margin, uint256 openedAt, uint256 maturity, bool settled)",
  "function nextPositionId() view returns (uint256)",
  "function amm() view returns (address)",
  "function margin() view returns (address)",
  "function oracle() view returns (address)",
  "function asset() view returns (address)",
  "function underlyingRate() view returns (address)",
  "function tenor() view returns (uint256)",
  "function initialMarginBps() view returns (uint256)",
]);

export const rateAmmAbi = parseAbi([
  "function quoteFixedRate(bool payFixed, uint256 notional) view returns (uint256)",
  "function lastImpliedRate() view returns (uint256)",
  "function netFixedExposure() view returns (int256)",
  "function totalLiquidity() view returns (uint256)",
  "function timeToMaturity() view returns (uint256)",
  "function maturity() view returns (uint256)",
]);

export const marginEngineAbi = parseAbi([
  "function collateral(address) view returns (uint256)",
  "function poolBalance() view returns (uint256)",
  "function maintenanceMarginBps() view returns (uint256)",
  "function isLiquidatable(uint256 postedMargin, uint256 notional, int256 pnl) view returns (bool)",
]);

export const yieldCurveAbi = parseAbi([
  "function rateForTenor(uint256 tenor) view returns (uint256)",
  "function numPoints() view returns (uint256)",
  "function points(uint256) view returns (uint256 tenor, uint256 fixedRate)",
  "function setPoint(uint256 index, uint256 fixedRate)",
  "function addPoint(uint256 tenor, uint256 fixedRate)",
]);

export const loanOriginatorAbi = parseAbi([
  "function fund(uint256 amount)",
  "function withdraw(uint256 amount)",
  "function originate(uint256 principal, uint256 duration, uint256 collateralAmount, uint256 hedgeMargin) returns (uint256)",
  "function repay(uint256 loanId)",
  "function quoteRate(uint256 duration) view returns (uint256)",
  "function accruedInterest(uint256 loanId) view returns (uint256)",
  "function lendable() view returns (uint256)",
  "function creditSpread() view returns (uint256)",
  "function deposits(address) view returns (uint256)",
  "function loans(uint256) view returns (address borrower, uint256 principal, uint256 fixedRate, uint256 startTime, uint256 maturity, uint256 hedgeSwapId, uint256 collateral, bool repaid)",
  "function nextLoanId() view returns (uint256)",
]);

export const erc20Abi = parseAbi([
  "function approve(address spender, uint256 amount) returns (bool)",
  "function allowance(address owner, address spender) view returns (uint256)",
  "function balanceOf(address owner) view returns (uint256)",
  "function decimals() view returns (uint8)",
]);
