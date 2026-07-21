import type { Address, PublicClient, WalletClient } from "viem";
import { CouponClient } from "./client.js";
import { SwapModule } from "./swap.js";
import { LoanModule } from "./loan.js";
import { CurveModule } from "./curve.js";
import { OracleModule } from "./oracle.js";
import { FactoryModule } from "./factory.js";

export * from "./types.js";
export * from "./math.js";
export * from "./abis.js";
export { CouponClient } from "./client.js";
export { SwapModule } from "./swap.js";
export { LoanModule } from "./loan.js";
export { CurveModule } from "./curve.js";
export { OracleModule } from "./oracle.js";
export { FactoryModule } from "./factory.js";

export class Coupon {
  readonly client: CouponClient;

  constructor(publicClient: PublicClient, walletClient?: WalletClient) {
    this.client = new CouponClient(publicClient, walletClient);
  }

  swap(market: Address): SwapModule {
    return new SwapModule(this.client, market);
  }

  loan(originator: Address, asset?: Address, margin?: Address): LoanModule {
    return new LoanModule(this.client, originator, asset, margin);
  }

  curve(address: Address): CurveModule {
    return new CurveModule(this.client, address);
  }

  oracle(address: Address): OracleModule {
    return new OracleModule(this.client, address);
  }

  factory(address: Address): FactoryModule {
    return new FactoryModule(this.client, address);
  }
}
