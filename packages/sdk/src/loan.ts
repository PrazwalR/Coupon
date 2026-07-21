import type { Address, Hash } from "viem";
import { CouponClient } from "./client.js";
import { loanOriginatorAbi, erc20Abi } from "./abis.js";
import type { Loan } from "./types.js";

export class LoanModule {
  constructor(
    private readonly client: CouponClient,
    public readonly address: Address,
    private readonly assetAddr?: Address,
    private readonly marginAddr?: Address,
  ) {}

  private pc() {
    return this.client.publicClient;
  }

  quoteRate(duration: bigint): Promise<bigint> {
    return this.pc().readContract({
      address: this.address,
      abi: loanOriginatorAbi,
      functionName: "quoteRate",
      args: [duration],
    });
  }

  accruedInterest(loanId: bigint): Promise<bigint> {
    return this.pc().readContract({
      address: this.address,
      abi: loanOriginatorAbi,
      functionName: "accruedInterest",
      args: [loanId],
    });
  }

  lendable(): Promise<bigint> {
    return this.pc().readContract({
      address: this.address,
      abi: loanOriginatorAbi,
      functionName: "lendable",
      args: [],
    });
  }

  creditSpread(): Promise<bigint> {
    return this.pc().readContract({
      address: this.address,
      abi: loanOriginatorAbi,
      functionName: "creditSpread",
      args: [],
    });
  }

  async getLoan(loanId: bigint): Promise<Loan> {
    const l = await this.pc().readContract({
      address: this.address,
      abi: loanOriginatorAbi,
      functionName: "loans",
      args: [loanId],
    });
    return {
      borrower: l[0],
      principal: l[1],
      fixedRate: l[2],
      startTime: l[3],
      maturity: l[4],
      hedgeSwapId: l[5],
      collateral: l[6],
      repaid: l[7],
    };
  }

  approveAsset(amount: bigint): Promise<Hash> {
    if (!this.assetAddr) throw new Error("asset address not provided to LoanModule");
    return this.client.write(this.assetAddr, erc20Abi, "approve", [this.address, amount]);
  }

  approveMargin(amount: bigint): Promise<Hash> {
    if (!this.assetAddr || !this.marginAddr) {
      throw new Error("asset and margin addresses required for approveMargin");
    }
    return this.client.write(this.assetAddr, erc20Abi, "approve", [this.marginAddr, amount]);
  }

  fund(amount: bigint): Promise<Hash> {
    return this.client.write(this.address, loanOriginatorAbi, "fund", [amount]);
  }

  withdraw(amount: bigint): Promise<Hash> {
    return this.client.write(this.address, loanOriginatorAbi, "withdraw", [amount]);
  }

  originate(
    principal: bigint,
    duration: bigint,
    collateralAmount: bigint,
    hedgeMargin: bigint,
  ): Promise<Hash> {
    return this.client.write(this.address, loanOriginatorAbi, "originate", [
      principal,
      duration,
      collateralAmount,
      hedgeMargin,
    ]);
  }

  repay(loanId: bigint): Promise<Hash> {
    return this.client.write(this.address, loanOriginatorAbi, "repay", [loanId]);
  }
}
