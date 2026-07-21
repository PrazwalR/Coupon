import type { Abi, Address, Hash, PublicClient, WalletClient } from "viem";

export class CouponClient {
  constructor(
    public readonly publicClient: PublicClient,
    public readonly walletClient?: WalletClient,
  ) {}

  async write(
    address: Address,
    abi: Abi,
    functionName: string,
    args: readonly unknown[],
  ): Promise<Hash> {
    const wc = this.walletClient;
    if (!wc || !wc.account) {
      throw new Error("walletClient with an account is required for writes");
    }
    const { request } = await this.publicClient.simulateContract({
      address,
      abi,
      functionName,
      args,
      account: wc.account,
    });
    return wc.writeContract(request);
  }
}
