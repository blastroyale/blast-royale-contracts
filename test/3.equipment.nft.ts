import { expect } from "chai";
import { BigNumber } from "ethers";
import { ethers, network } from "hardhat";

describe("Blast Equipment NFT", function () {
  let owner: any;
  let treasury: any;
  let addr1: any;
  let blt: any;
  let blst: any;
  let cs: any;

  beforeEach(async () => {
    [owner, treasury, addr1] = await ethers.getSigners();
    const CraftToken = await ethers.getContractFactory("SecondaryToken");
    cs = await CraftToken.deploy(
      "Craftship",
      "$CS",
      ethers.utils.parseEther("100000000")
    );
    await cs.deployed();
    await cs
      .connect(owner)
      .claim(addr1.address, ethers.utils.parseEther("10000"));

    const BlastToken = await ethers.getContractFactory("PrimaryToken");
    blst = await BlastToken.deploy(
      "Blast Royale",
      "$BLT",
      owner.address,
      treasury.address,
      ethers.utils.parseEther("512000000")
    );
    await blst.deployed();
    await blst
      .connect(treasury)
      .transfer(addr1.address, ethers.utils.parseEther("10000000"));

    const BlastEquipmentToken = await ethers.getContractFactory(
      "BlastEquipmentNFT"
    );
    blt = await BlastEquipmentToken.connect(owner).deploy(
      "Blast Equipment",
      "BLT",
      cs.address,
      blst.address
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
  });

    await blt.setTreasuryAddress(treasury.address);
    await blt.setCompanyAddress(treasury.address);
  });

  it("Test NFT", async function () {
    await blt.connect(owner).setLevel(0, 3);
    await blt.connect(owner).setRepairCount(0, 1);
    await blt.connect(owner).setReplicationCount(0, 4);

    expect(await blt.balanceOf(addr1.address)).to.equal(2);
    expect(await blt.tokenURI(0)).to.equal("ipfs://111");
    expect(await blt.tokenURI(1)).to.equal("ipfs://222");
    expect(await blt.hashValue(0)).to.equal(ethers.utils.keccak256("0x1000"));

    const nftAttributes = await blt.getAttributes(0);
    const level = nftAttributes[0].toNumber();
    const durabilityRemaining = nftAttributes[1].toNumber();
    const repairCount = nftAttributes[2].toNumber();
    const replicationCount = nftAttributes[3].toNumber();

    expect(level).to.equal(3);
    expect(durabilityRemaining).to.equal(0);
    expect(repairCount).to.equal(1);
    expect(replicationCount).to.equal(4);
  });

  it("Repair with cs Token", async () => {
    // Week 1. maxDurability: 96, durability: 1
    await network.provider.send("evm_increaseTime", [3600 * 24 * 7]);
    await network.provider.send("evm_mine");
    let nftAttributes = await blt.getAttributes(0);
    expect(nftAttributes[1].toNumber()).to.eq(1);
    let repairPrice = await blt.getRepairPrice(0);
    expect(repairPrice).to.gte(ethers.utils.parseEther("20"));

    // Week 2. maxDurability: 96, durability: 2
    await network.provider.send("evm_increaseTime", [3600 * 24 * 7]);
    await network.provider.send("evm_mine");
    nftAttributes = await blt.getAttributes(0);
    expect(nftAttributes[1].toNumber()).to.eq(2);
    repairPrice = await blt.getRepairPrice(0);
    expect(repairPrice).to.gte(ethers.utils.parseEther("113"));

    // We do Repair on Week 2. It gives us maxDurability: 96, durability: 0, durabilityRestored: 2
    await cs
      .connect(addr1)
      .approve(blt.address, ethers.utils.parseEther("114"));
    await blt.connect(addr1).repair(0);

    nftAttributes = await blt.getAttributes(0);
    const attributes = await blt.attributes(0);
    expect(attributes.durabilityRestored.toNumber()).to.eq(2);
    expect(nftAttributes[1].toNumber()).to.eq(0);
    repairPrice = await blt.getRepairPrice(0);
    expect(repairPrice.toNumber()).to.eq(0);

    // Week 3, maxDurability: 96, durability: 1, durabilityRestored: 2
    await network.provider.send("evm_increaseTime", [3600 * 24 * 7]);
    await network.provider.send("evm_mine");
    nftAttributes = await blt.getAttributes(0);
    expect(nftAttributes[1].toNumber()).to.eq(1);
    repairPrice = await blt.getRepairPrice(0);
    expect(repairPrice).to.gte(ethers.utils.parseEther("46"));

    // Week 95, maxDurability: 96, durability: 93, durabilityRestored: 2. On this week the item becomes unusable in game.
    await network.provider.send("evm_increaseTime", [3600 * 24 * 7 * 92]);
    await network.provider.send("evm_mine");
    nftAttributes = await blt.getAttributes(0);
    expect(nftAttributes[1].toNumber()).to.eq(93);
    repairPrice = await blt.getRepairPrice(0);
    console.log(repairPrice);
    expect(repairPrice).to.gte(ethers.utils.parseEther("3867388"));

    // Week 100, maxDurability: 96, durability: 96, durabilityRestored: 2
    await network.provider.send("evm_increaseTime", [3600 * 24 * 7 * 1]);
    await network.provider.send("evm_mine");
    nftAttributes = await blt.getAttributes(0);
    expect(nftAttributes[1].toNumber()).to.eq(94);
    repairPrice = await blt.getRepairPrice(0);
    expect(repairPrice).to.gte(ethers.utils.parseEther("3973360"));
  });

  it("Repair with BLST Token", async () => {
    // Week 1. maxDurability: 96, durability: 1
    await network.provider.send("evm_increaseTime", [3600 * 24 * 7]);
    await network.provider.send("evm_mine");
    let nftAttributes = await blt.getAttributes(0);
    expect(nftAttributes[1].toNumber()).to.eq(1);
    let repairPrice = await blt.getRepairPrice(0);
    expect(repairPrice).to.gte(ethers.utils.parseEther("20"));

    // Week 9. maxDurability: 96, durability: 9
    await network.provider.send("evm_increaseTime", [3600 * 24 * 7 * 8]);
    await network.provider.send("evm_mine");

    repairPrice = await blt.getRepairPriceBLST(0);
    await blst
      .connect(addr1)
      .approve(blt.address, repairPrice.sub(BigNumber.from("100")));
    await expect(blt.connect(addr1).repair(0)).to.revertedWith(
      "ERC20: insufficient allowance"
    );
    await blst.connect(addr1).approve(blt.address, repairPrice);
    await expect(blt.connect(addr1).repair(0)).to.emit(blt, "AttributeUpdated");

    // We do Repair on Week 9. It gives us maxDurability: 96, durability: 0, durabilityRestored: 9
    await network.provider.send("evm_increaseTime", [3600 * 24 * 7]);
    await network.provider.send("evm_mine");
    nftAttributes = await blt.getAttributes(0);
    const attributes = await blt.attributes(0);
    expect(attributes.durabilityRestored.toNumber()).to.eq(9);
    expect(nftAttributes[1].toNumber()).to.eq(1);
  });
});
