/* eslint-disable node/no-missing-import */
import { expect } from "chai";
import { BigNumber } from "ethers";
import { ethers, network } from "hardhat";
import { getContractArguments } from "../scripts/deploy/helper";

describe("Repairing Contract", () => {
  let owner: any, addr1: any;
  let bet: any;
  let blt: any;
  let cs: any;
  let repairing: any;

  beforeEach(async () => {
    [owner, addr1] = await ethers.getSigners();
    // BlastEquipment NFT Deploying
    const BlastEquipmentToken = await ethers.getContractFactory(
      "BlastEquipmentNFT"
    );
    bet = await BlastEquipmentToken.connect(owner).deploy(
      "Blast Equipment",
      "BLT"
    );
    await bet.deployed();

    // Blast Token Deploying
    const primaryTokenArgs = getContractArguments(network.name, "PrimaryToken");
    const BlastToken = await ethers.getContractFactory("PrimaryToken");
    blt = await BlastToken.deploy(
      primaryTokenArgs.name,
      primaryTokenArgs.symbol,
      owner.address, // owner address
      owner.address, // treasury address
      BigNumber.from(primaryTokenArgs.supply) // fixed supply 512M
    );
    await blt.deployed();
    await (
      await blt
        .connect(owner)
        .transfer(addr1.address, ethers.utils.parseEther("200"))
    ).wait();

    // CS Token deploying
    const secondaryTokenArgs = getContractArguments(
      network.name,
      "SecondaryToken"
    );
    const CraftToken = await ethers.getContractFactory("SecondaryToken");
    cs = await CraftToken.deploy(
      secondaryTokenArgs.name,
      secondaryTokenArgs.symbol,
      BigNumber.from(secondaryTokenArgs.supply),
      owner.address
    );
    await cs.deployed();
    await (
      await cs
        .connect(owner)
        .transfer(addr1.address, ethers.utils.parseEther("45000"))
    ).wait();

    // Scrapper Contract Deploying
    const repairingFactory = await ethers.getContractFactory("Repairing");
    repairing = await repairingFactory
      .connect(owner)
      .deploy(
        bet.address,
        blt.address,
        cs.address,
        owner.address,
        owner.address
      );
    await repairing.deployed();

    // Granting GAME ROLE role to Upgrader contract address
    const GAME_ROLE = await bet.GAME_ROLE();
    await bet.grantRole(GAME_ROLE, repairing.address);

    // Granting MINTER ROLE to cs contract
    const MINTER_ROLE = await cs.MINTER_ROLE();
    await cs.grantRole(MINTER_ROLE, repairing.address);

    // NFT equipment items minting
    const tx = await bet.connect(owner).safeMint(
      addr1.address,
      ["ipfs://111", "ipfs://222"],
      [ethers.utils.keccak256("0x1000"), ethers.utils.keccak256("0x2000")],
      ["ipfs://111_real", "ipfs://222_real"],
      [
        [0, 96, 9, 9, 5],
        [0, 96, 9, 9, 5],
      ]
    );
    await tx.wait();
  });

  it("Repair with cs Token", async () => {
    // Week 1. maxDurability: 96, durability: 1
    await network.provider.send("evm_increaseTime", [3600 * 24 * 7]);
    await network.provider.send("evm_mine");
    let nftAttributes = await bet.getAttributes(0);
    expect(nftAttributes[2].toNumber()).to.eq(1);
    let repairPrice = await repairing.getRepairPrice(0);
    expect(repairPrice).to.gte(ethers.utils.parseEther("20"));

    // Week 2. maxDurability: 96, durability: 2
    await network.provider.send("evm_increaseTime", [3600 * 24 * 7]);
    await network.provider.send("evm_mine");
    nftAttributes = await bet.getAttributes(0);
    expect(nftAttributes[2].toNumber()).to.eq(2);
    repairPrice = await repairing.getRepairPrice(0);
    expect(repairPrice).to.gte(ethers.utils.parseEther("113"));

    // We do Repair on Week 2. It gives us maxDurability: 96, durability: 0, durabilityRestored: 2
    await cs
      .connect(addr1)
      .approve(repairing.address, ethers.utils.parseEther("114"));
    await repairing.connect(addr1).repair(0);

    nftAttributes = await bet.getAttributes(0);
    expect(nftAttributes[1].toNumber()).to.eq(2);
    expect(nftAttributes[2].toNumber()).to.eq(0);
    repairPrice = await repairing.getRepairPrice(0);
    expect(repairPrice.toNumber()).to.eq(0);

    // Week 3, maxDurability: 96, durability: 1, durabilityRestored: 2
    await network.provider.send("evm_increaseTime", [3600 * 24 * 7]);
    await network.provider.send("evm_mine");
    nftAttributes = await bet.getAttributes(0);
    expect(nftAttributes[2].toNumber()).to.eq(1);
    repairPrice = await repairing.getRepairPrice(0);
    expect(repairPrice).to.gte(ethers.utils.parseEther("46"));

    // Week 95, maxDurability: 96, durability: 93, durabilityRestored: 2. On this week the item becomes unusable in game.
    await network.provider.send("evm_increaseTime", [3600 * 24 * 7 * 92]);
    await network.provider.send("evm_mine");
    nftAttributes = await bet.getAttributes(0);
    expect(nftAttributes[2].toNumber()).to.eq(93);
    repairPrice = await repairing.getRepairPrice(0);
    expect(repairPrice).to.gte(ethers.utils.parseEther("3867388"));

    // Week 100, maxDurability: 96, durability: 96, durabilityRestored: 2
    await network.provider.send("evm_increaseTime", [3600 * 24 * 7 * 1]);
    await network.provider.send("evm_mine");
    nftAttributes = await bet.getAttributes(0);
    expect(nftAttributes[2].toNumber()).to.eq(94);
    repairPrice = await repairing.getRepairPrice(0);
    expect(repairPrice).to.gte(ethers.utils.parseEther("3973360"));
  });

  it("Repair with BLST Token", async () => {
    // Week 1. maxDurability: 96, durability: 1
    await network.provider.send("evm_increaseTime", [3600 * 24 * 7]);
    await network.provider.send("evm_mine");
    let nftAttributes = await bet.getAttributes(0);
    expect(nftAttributes[2].toNumber()).to.eq(1);
    let repairPrice = await repairing.getRepairPrice(0);
    expect(repairPrice).to.gte(ethers.utils.parseEther("20"));

    // Week 9. maxDurability: 96, durability: 9
    await network.provider.send("evm_increaseTime", [3600 * 24 * 7 * 8]);
    await network.provider.send("evm_mine");

    repairPrice = await repairing.getRepairPriceBLST(0);
    await blt
      .connect(addr1)
      .approve(repairing.address, repairPrice.sub(BigNumber.from("100")));
    await expect(repairing.connect(addr1).repair(0)).to.revertedWith(
      "ERC20: insufficient allowance"
    );
    await blt.connect(addr1).approve(repairing.address, repairPrice);
    await expect(repairing.connect(addr1).repair(0)).to.emit(
      repairing,
      "Repaired"
    );

    // We do Repair on Week 9. It gives us maxDurability: 96, durability: 0, durabilityRestored: 9
    await network.provider.send("evm_increaseTime", [3600 * 24 * 7]);
    await network.provider.send("evm_mine");
    nftAttributes = await bet.getAttributes(0);
    expect(nftAttributes[1].toNumber()).to.eq(9);
    expect(nftAttributes[2].toNumber()).to.eq(1);
  });
});
