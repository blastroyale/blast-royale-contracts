import { expect } from "chai";
import { ethers } from "hardhat";

// const uri = "https://blastroyale.com/nft/";

describe("Blast LootBox Contract", function () {
  it("Open function test", async function () {
    const [owner] = await ethers.getSigners();
    // BlastEquipment NFT Deploying
    const BlastEquipmentToken = await ethers.getContractFactory(
      "BlastEquipmentNFT"
    );
    const bet = await BlastEquipmentToken.connect(owner).deploy(
      "Blast Equipment",
      "BLT"
    );
    await bet.deployed();

    // BlastLootbox NFT Deploying
    const BlastLootBox = await ethers.getContractFactory("BlastLootBox");
    const blb = await BlastLootBox.connect(owner).deploy(
      "Blast LootBox",
      "BLB",
      bet.address
    );
    await blb.deployed();

    // Equipment NFT minting process
    const mintTx = await bet
      .connect(owner)
      .safeMint(
        blb.address,
        ["ipfs://111", "ipfs://222", "ipfs://333"],
        [
          ethers.utils.keccak256("0x1000"),
          ethers.utils.keccak256("0x2000"),
          ethers.utils.keccak256("0x3000"),
        ]
      );
    await mintTx.wait();

    // Lootbox Minting to address with Equipment NFT ids [0, 1, 2]
    const tx = await blb.connect(owner).safeMint(
      [owner.address],
      ["ipfs://111"],
      [
        {
          token0: ethers.BigNumber.from("0"),
          token1: ethers.BigNumber.from("1"),
          token2: ethers.BigNumber.from("2"),
        },
      ]
    );
    await tx.wait();

    // Lootbox contract has 3 Equipment NFT items
    expect(await bet.balanceOf(blb.address)).to.equal(3);
    // Owner don't have Equipment NFT
    expect(await bet.balanceOf(owner.address)).to.equal(0);
    // Owner only have 1 Lootbox NFT
    expect(await blb.balanceOf(owner.address)).to.equal(1);

    // Owner opens the Lootbox
    const openTx = await blb.connect(owner).open(0);
    await openTx.wait();

    // Now, 3 Equipment items which Lootbox contract had transferred to Owner
    expect(await bet.balanceOf(blb.address)).to.equal(0);
    // Owner balance of Equipment NFT is 3
    expect(await bet.balanceOf(owner.address)).to.equal(3);
    // Owner has no Lootbox NFT because it's already burnt
    expect(await blb.balanceOf(owner.address)).to.equal(0);
  });
});
