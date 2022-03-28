"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const cucumber_1 = require("@cucumber/cucumber");
const ethereum_waffle_1 = require("ethereum-waffle");
const chai_1 = require("chai");
const BlastNFT_json_1 = __importDefault(require("../../artifacts/contracts/BlastNFT.sol/BlastNFT.json"));
(0, chai_1.use)(ethereum_waffle_1.solidity);
(0, cucumber_1.setDefaultTimeout)(20 * 1000);
class BlastNFTWorld {
    constructor() {
        this.ready = false;
        this.wallets = new ethereum_waffle_1.MockProvider().getWallets();
        this.owner = this.wallets[0].address;
        this.minterRole = "";
        const that = this;
        this._initialized = new Promise(async (resolve, reject) => {
            try {
                that.blastct = (await (0, ethereum_waffle_1.deployContract)(that.wallets[0], BlastNFT_json_1.default, ["Blast NFT", "BNFT", "https://"]));
                that.ready = true;
                that.minterRole = await that.blastct.MINTER_ROLE();
                resolve(true);
            }
            catch (err) {
                reject(err);
            }
        });
    }
}
(0, cucumber_1.setWorldConstructor)(BlastNFTWorld);
