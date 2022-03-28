import { setWorldConstructor, setDefaultTimeout } from "@cucumber/cucumber";
import { deployContract, MockProvider, solidity } from "ethereum-waffle";
import { use } from "chai";
import BlastNFTContract from "../../artifacts/contracts/BlastNFT.sol/BlastNFT.json";
import { BlastNFT } from "../../typechain/BlastNFT";
import { Wallet } from "ethers";

use(solidity);

setDefaultTimeout(20 * 1000);

class BlastNFTWorld {
  public owner: string;
  public minterRole: string;
  public wallets: Wallet[];
  public blastct: BlastNFT | undefined;
  public ready: boolean = false;
  private _initialized: Promise<boolean>;

  constructor() {
    this.wallets = new MockProvider().getWallets();
    this.owner = this.wallets[0].address;
    this.minterRole = "";

    const that = this;
    this._initialized = new Promise(async (resolve, reject) => {
      try {
        that.blastct = (await deployContract(
          that.wallets[0],
          BlastNFTContract,
          ["Blast NFT", "BNFT", "https://"]
        )) as BlastNFT;
        that.ready = true;
        that.minterRole = await that.blastct.MINTER_ROLE();
        resolve(true);
      } catch (err) {
        reject(err);
      }
    });
  }
}

setWorldConstructor(BlastNFTWorld);
