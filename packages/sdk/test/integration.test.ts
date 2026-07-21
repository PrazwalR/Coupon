import { test, before, after } from "node:test";
import assert from "node:assert/strict";
import { spawn, execSync, type ChildProcess } from "node:child_process";
import { fileURLToPath } from "node:url";
import { createPublicClient, createWalletClient, http, type Hex } from "viem";
import { privateKeyToAccount } from "viem/accounts";
import { Coupon, Side, WAD } from "../src/index.js";

const RPC = "http://127.0.0.1:8545";
const KEY = "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80" as Hex;
const YEAR2 = 730n * 24n * 60n * 60n;
const contractsDir = fileURLToPath(new URL("../../../contracts", import.meta.url));

let anvil: ChildProcess | undefined;
const addr: Record<string, `0x${string}`> = {};

async function waitForRpc(): Promise<boolean> {
  for (let i = 0; i < 50; i++) {
    try {
      const res = await fetch(RPC, {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({ jsonrpc: "2.0", id: 1, method: "eth_blockNumber", params: [] }),
      });
      if (res.ok) return true;
    } catch {}
    await new Promise((r) => setTimeout(r, 200));
  }
  return false;
}

before(async () => {
  anvil = spawn("anvil", ["--port", "8545", "--silent"], { stdio: "ignore" });
  const up = await waitForRpc();
  if (!up) throw new Error("anvil did not start");
  const out = execSync(
    `forge script script/Deploy.s.sol --rpc-url ${RPC} --broadcast --private-key ${KEY} --skip-simulation`,
    { cwd: contractsDir, encoding: "utf8", env: { ...process.env, PRIVATE_KEY: KEY } },
  );
  for (const m of out.matchAll(/(TOKEN|ORACLE|FACTORY|MARKET|CURVE|ORIGINATOR)=(0x[0-9a-fA-F]{40})/g)) {
    addr[m[1]!] = m[2]! as `0x${string}`;
  }
});

after(() => {
  anvil?.kill("SIGKILL");
});

test("SDK reads deployed protocol state", async () => {
  const pc = createPublicClient({ transport: http(RPC) });
  const sdk = new Coupon(pc);

  assert.equal(await sdk.factory(addr.FACTORY!).marketCount(), 1n);
  assert.equal(await sdk.curve(addr.CURVE!).rateForTenor(YEAR2), (WAD * 75n) / 1000n);
  assert.equal(await sdk.loan(addr.ORIGINATOR!).lendable(), 200_000n * WAD);
  assert.equal(await sdk.loan(addr.ORIGINATOR!).quoteRate(YEAR2), (WAD * 95n) / 1000n);

  const swap = sdk.swap(addr.MARKET!);
  assert.equal(await swap.totalLiquidity(), 500_000n * WAD);
  assert.ok((await swap.quoteFixedRate(true, 1000n * WAD)) > 0n);
});

test("SDK write path: open a swap and read the position back", async () => {
  const account = privateKeyToAccount(KEY);
  const pc = createPublicClient({ transport: http(RPC) });
  const wc = createWalletClient({ account, transport: http(RPC) });
  const sdk = new Coupon(pc, wc);
  const swap = sdk.swap(addr.MARKET!);

  const before = await swap.nextPositionId();
  const hash = await swap.openSwap(Side.PAY_FIXED, 1000n * WAD, 100n * WAD);
  await pc.waitForTransactionReceipt({ hash });

  const pos = await swap.getPosition(before);
  assert.equal(pos.notional, 1000n * WAD);
  assert.equal(pos.side, Side.PAY_FIXED);
  assert.equal(pos.owner.toLowerCase(), account.address.toLowerCase());
  assert.ok(pos.fixedRate > 0n);
});
