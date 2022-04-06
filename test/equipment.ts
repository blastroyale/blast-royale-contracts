import { expect } from "chai";
import { ethers } from "hardhat";

// const uri = "https://blastroyale.com/nft/";

describe("Blast Equipment NFT", function () {
  it("Test NFT", async function () {
    // Getting signer
    const [owner, addr1] = await ethers.getSigners();

    const BlastEquipmentToken = await ethers.getContractFactory(
      "BlastEquipmentNFT"
    );
    const blt = await BlastEquipmentToken.connect(owner).deploy(
      "Blast Equipment",
      "BLT"
    );
    await blt.deployed();

    const tx = await blt
      .connect(owner)
      .safeMint(
        addr1.address,
        ["ipfs://111", "ipfs://222"],
        [ethers.utils.keccak256("0x1000"), ethers.utils.keccak256("0x2000")]
      );
    await tx.wait();

    console.log(await blt.attributes(0));

    await blt.connect(owner).setAttribute(0, {
      level: 2,
      durabilityRemaining: 2,
      repairCount: 2,
      replicationCount: 1,
    });

    console.log(await blt.attributes(0));
    expect(await blt.balanceOf(addr1.address)).to.equal(2);
    expect(await blt.tokenURI(0)).to.equal("ipfs://111");
    expect(await blt.tokenURI(1)).to.equal("ipfs://222");
    expect(await blt.hashValue(0)).to.equal(ethers.utils.keccak256("0x1000"));
  });
});
