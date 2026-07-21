import { test } from "node:test";
import assert from "node:assert/strict";
import {
  WAD,
  fixedAccrual,
  pnl,
  requiredMargin,
  isLiquidatable,
  bpsToWad,
  wadToBps,
  marketId,
} from "../src/math.js";
import { Side, type MarketParams } from "../src/types.js";

test("fixedAccrual matches SwapMath", () => {
  assert.equal(fixedAccrual(WAD / 10n, 365n * 24n * 3600n), WAD / 10n);
  assert.equal(fixedAccrual(WAD / 10n, (365n * 24n * 3600n) / 2n), WAD / 20n);
});

test("pnl is zero-sum between payer and receiver", () => {
  const fr = (WAD * 22n) / 100n;
  const fx = (WAD * 14n) / 100n;
  const notional = 1000n * WAD;
  const payer = pnl(true, fr, fx, notional);
  const receiver = pnl(false, fr, fx, notional);
  assert.equal(payer, -receiver);
  assert.equal(payer, 80n * WAD);
});

test("pnl sign follows rates", () => {
  const n = 1000n * WAD;
  assert.ok(pnl(true, (WAD * 10n) / 100n, (WAD * 7n) / 100n, n) > 0n);
  assert.ok(pnl(true, (WAD * 5n) / 100n, (WAD * 7n) / 100n, n) < 0n);
});

test("requiredMargin", () => {
  assert.equal(requiredMargin(1000n * WAD, 1000n), 100n * WAD);
});

test("isLiquidatable boundary", () => {
  const margin = 100n * WAD;
  const notional = 1000n * WAD;
  assert.equal(isLiquidatable(margin, notional, -50n * WAD, 500n), false);
  assert.equal(isLiquidatable(margin, notional, -50n * WAD - 1n, 500n), true);
});

test("bps <-> wad", () => {
  assert.equal(bpsToWad(700), (WAD * 7n) / 100n);
  assert.equal(wadToBps((WAD * 7n) / 100n), 700);
});

test("marketId matches on-chain keccak(abi.encode(...))", () => {
  const p: MarketParams = {
    rateOracle: "0x0000000000000000000000000000000000000001",
    asset: "0x0000000000000000000000000000000000000002",
    underlyingRate: "0x0000000000000000000000000000000000000002",
    tenor: 63072000n,
    initialMarginBps: 1000n,
    maintenanceMarginBps: 500n,
    initialFixedRate: (WAD * 7n) / 100n,
    baseScalar: 100n * WAD,
    liquidityFeeBps: 10n,
  };
  assert.equal(
    marketId(p),
    "0x2065180993e8daf4807dbeaf7893d0897344d57984b50f4396af7ff967d842a4",
  );
});

test("Side enum values match contract", () => {
  assert.equal(Side.PAY_FIXED, 0);
  assert.equal(Side.RECEIVE_FIXED, 1);
});
