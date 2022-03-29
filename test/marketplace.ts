import { expect } from "chai";
import { ethers } from "hardhat";

const uri = "https://blastroyale.com/nft/";

describe("Blast Royale Marketplace", function () {
  let blt: any;
  let nft: any;
  let market: any;
  let admin: any;
  let player1: any;
  let player2: any;

  before("deploying", async () => {
    const signers = await ethers.getSigners();
    admin = signers[0];
    player1 = signers[1];
    player2 = signers[2];
  });

  it("Deploy Primary Token", async function () {
    const BlastToken = await ethers.getContractFactory("PrimaryToken");
    blt = await BlastToken.deploy(
      "Blast Royale",
      "$BLT",
      admin.address,
      ethers.utils.parseEther("100000000")
    );
    await blt.deployed();
    await blt
      .connect(admin)
      .transfer(player2.address, ethers.utils.parseUnits("100"));
  });

  it("Deploy NFT", async function () {
    const BlastNFT = await ethers.getContractFactory("BlastNFT");
    nft = await BlastNFT.connect(admin).deploy("Blast Royale", "$BLT", uri);
    await nft.deployed();
    nft.connect(admin).mint(player1.address);
    nft.connect(admin).mint(player1.address);
  });

  it("Deploy Marketplace", async function () {
    const BlastNFT = await ethers.getContractFactory("Marketplace");
    market = await BlastNFT.connect(admin).deploy(nft.address, blt.address);
    await market.deployed();
  });

  it("List an NFT to sell", async function () {
    await nft.connect(player1).approve(market.address, 0);
    await market.connect(player1).addListing(0, ethers.utils.parseUnits("10"));
  });

  it("Buy an NFT", async function () {
    await blt
      .connect(player2)
      .approve(market.address, ethers.utils.parseUnits("10"));
    // await market.connect(player2).buy(listingId);
  });
});
