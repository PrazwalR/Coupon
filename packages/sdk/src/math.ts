import { encodeAbiParameters, keccak256, type Hex } from "viem";
import type { MarketParams } from "./types.js";

export const WAD = 10n ** 18n;
export const YEAR = 365n * 24n * 60n * 60n;
export const BPS = 10_000n;

export function fixedAccrual(rate: bigint, elapsed: bigint): bigint {
  return (rate * elapsed) / YEAR;
}

export function pnl(
  payFixed: boolean,
  floatingReturn: bigint,
  fixedAccrued: bigint,
  notional: bigint,
): bigint {
  const legDiff = floatingReturn - fixedAccrued;
  const frac = payFixed ? legDiff : -legDiff;
  return (frac * notional) / WAD;
}

export function requiredMargin(notional: bigint, bps: bigint): bigint {
  return (notional * bps) / BPS;
}

export function equity(postedMargin: bigint, currentPnl: bigint): bigint {
  return postedMargin + currentPnl;
}

export function isLiquidatable(
  postedMargin: bigint,
  notional: bigint,
  currentPnl: bigint,
  maintenanceBps: bigint,
): boolean {
  return equity(postedMargin, currentPnl) < (notional * maintenanceBps) / BPS;
}

export function bpsToWad(bps: number): bigint {
  return (BigInt(Math.round(bps)) * WAD) / BPS;
}

export function wadToBps(wad: bigint): number {
  return Number((wad * BPS) / WAD);
}

export function wadToNumber(wad: bigint): number {
  return Number(wad) / 1e18;
}

export function marketId(p: MarketParams): Hex {
  const encoded = encodeAbiParameters(
    [
      { type: "address" },
      { type: "address" },
      { type: "address" },
      { type: "uint256" },
      { type: "uint256" },
    ],
    [p.rateOracle, p.asset, p.underlyingRate, p.tenor, p.initialMarginBps],
  );
  return keccak256(encoded);
}
