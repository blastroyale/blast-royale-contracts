import { expect } from "chai";
import { ethers, network } from "hardhat";

// const uri = "https://blastroyale.com/nft/";

describe("Blast Equipment NFT", function () {
  let owner: any;
  let addr1: any;
  let blt: any;
  before("deploying", async () => {
    const signers = await ethers.getSigners();
    [owner, addr1] = signers;
  });
  it("Test NFT", async function () {
    const BlastEquipmentToken = await ethers.getContractFactory(
      "BlastEquipmentNFT"
    );
    blt = await BlastEquipmentToken.connect(owner).deploy(
      "Blast Equipment",
      "BLT"
    );
    await blt.deployed();

    const tx = await blt
      .connect(owner)
      .safeMint(
        addr1.address,
        ["ipfs://111", "ipfs://222"],
        [ethers.utils.keccak256("0x1000"), ethers.utils.keccak256("0x2000")],
        ["ipfs://111_real", "ipfs://222_real"]
      );
    await tx.wait();

    await blt.connect(owner).setLevel(0, 3);
    // await blt.connect(owner).extendDurability(0);
    await blt.connect(owner).setRepairCount(0, 1);
    await blt.connect(owner).setReplicationCount(0, 4);

    expect(await blt.balanceOf(addr1.address)).to.equal(2);
    expect(await blt.tokenURI(0)).to.equal("ipfs://111");
    expect(await blt.tokenURI(1)).to.equal("ipfs://222");
    expect(await blt.hashValue(0)).to.equal(ethers.utils.keccak256("0x1000"));

    let nftAttributes = await blt.getAttributes(0);
    const level = nftAttributes[0].toNumber();
    const durabilityRemaining = nftAttributes[1].toNumber();
    const repairCount = nftAttributes[2].toNumber();
    const replicationCount = nftAttributes[3].toNumber();
    expect(level).to.equal(3);
    expect(durabilityRemaining).to.equal(0);
    expect(repairCount).to.equal(1);
    expect(replicationCount).to.equal(4);

    // Time increase to test morphTo function
    // Week 1. maxDurability: 96, durability: 1
    await network.provider.send("evm_increaseTime", [3600 * 24 * 7]);
    await network.provider.send("evm_mine");
    nftAttributes = await blt.getAttributes(0);
    expect(nftAttributes[1].toNumber()).to.eq(1);

    // Week 2. maxDurability: 96, durability: 2
    await network.provider.send("evm_increaseTime", [3600 * 24 * 7]);
    await network.provider.send("evm_mine");
    nftAttributes = await blt.getAttributes(0);
    expect(nftAttributes[1].toNumber()).to.eq(2);

    // We do Repair on Week 2. It gives us maxDurability: 96, durability: 0, durabilityRestored: 2
    await blt.extendDurability(0);

    nftAttributes = await blt.getAttributes(0);
    const attributes = await blt.attributes(0);
    expect(attributes.durabilityRestored.toNumber()).to.eq(2);
    expect(nftAttributes[1].toNumber()).to.eq(0);

    // Week 3, maxDurability: 96, durability: 1, durabilityRestored: 2
    await network.provider.send("evm_increaseTime", [3600 * 24 * 7]);
    await network.provider.send("evm_mine");
    nftAttributes = await blt.getAttributes(0);
    expect(nftAttributes[1].toNumber()).to.eq(1);

    // Week 98, maxDurability: 96, durability: 96, durabilityRestored: 2. On this week the item becomes unusable in game.
    await network.provider.send("evm_increaseTime", [3600 * 24 * 7 * 95]);
    await network.provider.send("evm_mine");
    nftAttributes = await blt.getAttributes(0);
    expect(nftAttributes[1].toNumber()).to.eq(96);

    // Week 100, maxDurability: 96, durability: 96, durabilityRestored: 2
    await network.provider.send("evm_increaseTime", [3600 * 24 * 7 * 2]);
    await network.provider.send("evm_mine");
    nftAttributes = await blt.getAttributes(0);
    expect(nftAttributes[1].toNumber()).to.eq(96);
  });
});
