import { expect } from "chai";
import { ethers } from "hardhat";

// const uri = "https://blastroyale.com/nft/";

describe("Blast Royale Token", function () {
  it("Test NFT", async function () {
    const [owner, addr1] = await ethers.getSigners();
    const BlastToken = await ethers.getContractFactory("BlastNFT");
    const blt = await BlastToken.connect(owner).deploy("Blast Royale", "$BLT");
    await blt.deployed();

    const tx = await blt.connect(owner).safeMint(addr1.address, "ipfs://111");
    await tx.wait();

    expect(await blt.balanceOf(addr1.address)).to.equal(1);
    expect(await blt.tokenURI(0)).to.equal("ipfs://111");
  });
});
