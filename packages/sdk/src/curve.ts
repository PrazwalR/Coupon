import type { Address, Hash } from "viem";
import { CouponClient } from "./client.js";
import { yieldCurveAbi } from "./abis.js";
import type { CurvePoint } from "./types.js";

export class CurveModule {
  constructor(
    private readonly client: CouponClient,
    public readonly address: Address,
  ) {}

  rateForTenor(tenor: bigint): Promise<bigint> {
    return this.client.publicClient.readContract({
      address: this.address,
      abi: yieldCurveAbi,
      functionName: "rateForTenor",
      args: [tenor],
    });
  }

  numPoints(): Promise<bigint> {
    return this.client.publicClient.readContract({
      address: this.address,
      abi: yieldCurveAbi,
      functionName: "numPoints",
      args: [],
    });
  }

  async point(index: bigint): Promise<CurvePoint> {
    const [tenor, fixedRate] = await this.client.publicClient.readContract({
      address: this.address,
      abi: yieldCurveAbi,
      functionName: "points",
      args: [index],
    });
    return { tenor, fixedRate };
  }

  async points(): Promise<CurvePoint[]> {
    const n = await this.numPoints();
    const out: CurvePoint[] = [];
    for (let i = 0n; i < n; i++) {
      out.push(await this.point(i));
    }
    return out;
  }

  setPoint(index: bigint, fixedRate: bigint): Promise<Hash> {
    return this.client.write(this.address, yieldCurveAbi, "setPoint", [index, fixedRate]);
  }

  addPoint(tenor: bigint, fixedRate: bigint): Promise<Hash> {
    return this.client.write(this.address, yieldCurveAbi, "addPoint", [tenor, fixedRate]);
  }
}
