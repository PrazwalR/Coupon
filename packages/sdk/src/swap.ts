import type { Address, Hash } from "viem";
import { CouponClient } from "./client.js";
import { swapMarketAbi, rateAmmAbi, marginEngineAbi, erc20Abi } from "./abis.js";
import { Side, type Position } from "./types.js";

export class SwapModule {
  private ammAddr?: Address;
  private marginAddr?: Address;
  private assetAddr?: Address;

  constructor(
    private readonly client: CouponClient,
    public readonly address: Address,
  ) {}

  private pc() {
    return this.client.publicClient;
  }

  async amm(): Promise<Address> {
    if (!this.ammAddr) {
      this.ammAddr = await this.pc().readContract({
        address: this.address,
        abi: swapMarketAbi,
        functionName: "amm",
        args: [],
      });
    }
    return this.ammAddr;
  }

  async marginEngine(): Promise<Address> {
    if (!this.marginAddr) {
      this.marginAddr = await this.pc().readContract({
        address: this.address,
        abi: swapMarketAbi,
        functionName: "margin",
        args: [],
      });
    }
    return this.marginAddr;
  }

  async asset(): Promise<Address> {
    if (!this.assetAddr) {
      this.assetAddr = await this.pc().readContract({
        address: this.address,
        abi: swapMarketAbi,
        functionName: "asset",
        args: [],
      });
    }
    return this.assetAddr;
  }

  async quoteFixedRate(payFixed: boolean, notional: bigint): Promise<bigint> {
    return this.pc().readContract({
      address: await this.amm(),
      abi: rateAmmAbi,
      functionName: "quoteFixedRate",
      args: [payFixed, notional],
    });
  }

  async netExposure(): Promise<bigint> {
    return this.pc().readContract({
      address: await this.amm(),
      abi: rateAmmAbi,
      functionName: "netFixedExposure",
      args: [],
    });
  }

  async totalLiquidity(): Promise<bigint> {
    return this.pc().readContract({
      address: await this.amm(),
      abi: rateAmmAbi,
      functionName: "totalLiquidity",
      args: [],
    });
  }

  currentPnl(id: bigint): Promise<bigint> {
    return this.pc().readContract({
      address: this.address,
      abi: swapMarketAbi,
      functionName: "currentPnl",
      args: [id],
    });
  }

  async getPosition(id: bigint): Promise<Position> {
    const p = await this.pc().readContract({
      address: this.address,
      abi: swapMarketAbi,
      functionName: "positions",
      args: [id],
    });
    return {
      owner: p[0],
      side: p[1] as Side,
      notional: p[2],
      fixedRate: p[3],
      accumulatorAtOpen: p[4],
      margin: p[5],
      openedAt: p[6],
      maturity: p[7],
      settled: p[8],
    };
  }

  nextPositionId(): Promise<bigint> {
    return this.pc().readContract({
      address: this.address,
      abi: swapMarketAbi,
      functionName: "nextPositionId",
      args: [],
    });
  }

  async isLiquidatable(id: bigint): Promise<boolean> {
    const [pos, pnl, margin] = await Promise.all([
      this.getPosition(id),
      this.currentPnl(id),
      this.marginEngine(),
    ]);
    return this.pc().readContract({
      address: margin,
      abi: marginEngineAbi,
      functionName: "isLiquidatable",
      args: [pos.margin, pos.notional, pnl],
    });
  }

  async approveMargin(amount: bigint): Promise<Hash> {
    const [asset, margin] = await Promise.all([this.asset(), this.marginEngine()]);
    return this.client.write(asset, erc20Abi, "approve", [margin, amount]);
  }

  openSwap(side: Side, notional: bigint, marginAmount: bigint): Promise<Hash> {
    return this.client.write(this.address, swapMarketAbi, "openSwap", [side, notional, marginAmount]);
  }

  settle(id: bigint): Promise<Hash> {
    return this.client.write(this.address, swapMarketAbi, "settle", [id]);
  }

  liquidate(id: bigint): Promise<Hash> {
    return this.client.write(this.address, swapMarketAbi, "liquidate", [id]);
  }

  provideLiquidity(amount: bigint): Promise<Hash> {
    return this.client.write(this.address, swapMarketAbi, "provideLiquidity", [amount]);
  }
}
