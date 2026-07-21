import type { Address, Hash } from "viem";
import { CouponClient } from "./client.js";
import { rateOracleAbi } from "./abis.js";

export class OracleModule {
  constructor(
    private readonly client: CouponClient,
    public readonly address: Address,
  ) {}

  getRate(asset: Address): Promise<bigint> {
    return this.client.publicClient.readContract({
      address: this.address,
      abi: rateOracleAbi,
      functionName: "getRate",
      args: [asset],
    });
  }

  currentAccumulator(asset: Address): Promise<bigint> {
    return this.client.publicClient.readContract({
      address: this.address,
      abi: rateOracleAbi,
      functionName: "currentAccumulator",
      args: [asset],
    });
  }

  floatingReturn(asset: Address, accStart: bigint): Promise<bigint> {
    return this.client.publicClient.readContract({
      address: this.address,
      abi: rateOracleAbi,
      functionName: "floatingReturn",
      args: [asset, accStart],
    });
  }

  updateIndex(asset: Address, newRate: bigint): Promise<Hash> {
    return this.client.write(this.address, rateOracleAbi, "updateIndex", [asset, newRate]);
  }
}
