import { expect } from "chai";
import { ethers } from "hardhat";

// const uri = "https://blastroyale.com/nft/";

describe("Blast LootBox", function () {
  it("Test NFT", async function () {
    const [owner] = await ethers.getSigners();
    const BlastLookBox = await ethers.getContractFactory("BlastLootBox");
    const blb = await BlastLookBox.connect(owner).deploy(
      "Blast LootBox",
      "BLB"
    );
    await blb.deployed();

    const tx = await blb
      .connect(owner)
      .safeMint(owner.address, "ipfs://111", [1, 2, 3]);
    await tx.wait();

    expect(await blb.balanceOf(owner.address)).to.equal(1);
    expect(await blb.tokenURI(0)).to.equal("ipfs://111");
  });
});
