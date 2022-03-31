import { expect } from "chai";
import { ethers } from "hardhat";

// const uri = "https://blastroyale.com/nft/";

describe("Blast Royale LootBox", function () {
  it("Test NFT", async function () {
    const [owner] = await ethers.getSigners();
    const BlastToken = await ethers.getContractFactory("BlastNFT");
    const blt = await BlastToken.connect(owner).deploy("Blast Royale", "$BLT");
    await blt.deployed();

    const tx = await blt.connect(owner).safeMint(owner.address, "ipfs://111");
    await tx.wait();

    expect(await blt.balanceOf(owner.address)).to.equal(1);
    expect(await blt.tokenURI(0)).to.equal("ipfs://111");
  });
});
