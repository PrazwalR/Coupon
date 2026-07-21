import type { Address, Hash, Hex } from "viem";
import { CouponClient } from "./client.js";
import { marketFactoryAbi } from "./abis.js";
import type { MarketParams } from "./types.js";

export class FactoryModule {
  constructor(
    private readonly client: CouponClient,
    public readonly address: Address,
  ) {}

  marketId(params: MarketParams): Promise<Hex> {
    return this.client.publicClient.readContract({
      address: this.address,
      abi: marketFactoryAbi,
      functionName: "marketId",
      args: [params],
    });
  }

  marketAt(id: Hex): Promise<Address> {
    return this.client.publicClient.readContract({
      address: this.address,
      abi: marketFactoryAbi,
      functionName: "markets",
      args: [id],
    });
  }

  marketCount(): Promise<bigint> {
    return this.client.publicClient.readContract({
      address: this.address,
      abi: marketFactoryAbi,
      functionName: "marketCount",
      args: [],
    });
  }

  allMarkets(index: bigint): Promise<Address> {
    return this.client.publicClient.readContract({
      address: this.address,
      abi: marketFactoryAbi,
      functionName: "allMarkets",
      args: [index],
    });
  }

  createMarket(params: MarketParams): Promise<Hash> {
    return this.client.write(this.address, marketFactoryAbi, "createMarket", [params]);
  }
}
