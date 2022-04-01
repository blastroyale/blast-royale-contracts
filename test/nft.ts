import { expect } from "chai";
import { ethers } from "hardhat";

// const uri = "https://blastroyale.com/nft/";

describe("Blast Royale Token", function () {
  it("Test NFT", async function () {
    const [owner, addr1] = await ethers.getSigners();
    const BlastToken = await ethers.getContractFactory("BlastNFT");
    const blt = await BlastToken.connect(owner).deploy("Blast Royale", "$BLT");
    await blt.deployed();

    const tx = await blt
      .connect(owner)
      .safeMint(
        addr1.address,
        ["ipfs://111", "ipfs://222"],
        [ethers.utils.keccak256("0x1000"), ethers.utils.keccak256("0x2000")]
      );
    await tx.wait();

    expect(await blt.balanceOf(addr1.address)).to.equal(2);
    expect(await blt.tokenURI(0)).to.equal("ipfs://111");
    expect(await blt.tokenURI(1)).to.equal("ipfs://222");
    expect(await blt.seeds(0)).to.equal(ethers.utils.keccak256("0x1000"));
  });
});
