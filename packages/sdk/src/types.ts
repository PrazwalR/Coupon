import type { Address } from "viem";

export enum Side {
  PAY_FIXED = 0,
  RECEIVE_FIXED = 1,
}

export interface MarketParams {
  rateOracle: Address;
  asset: Address;
  underlyingRate: Address;
  tenor: bigint;
  initialMarginBps: bigint;
  maintenanceMarginBps: bigint;
  initialFixedRate: bigint;
  baseScalar: bigint;
  liquidityFeeBps: bigint;
}

export interface Position {
  owner: Address;
  side: Side;
  notional: bigint;
  fixedRate: bigint;
  accumulatorAtOpen: bigint;
  margin: bigint;
  openedAt: bigint;
  maturity: bigint;
  settled: boolean;
}

export interface Loan {
  borrower: Address;
  principal: bigint;
  fixedRate: bigint;
  startTime: bigint;
  maturity: bigint;
  hedgeSwapId: bigint;
  collateral: bigint;
  repaid: boolean;
}

export interface CurvePoint {
  tenor: bigint;
  fixedRate: bigint;
}
