/* eslint-disable node/no-missing-import */
import { expect } from "chai";
import { BigNumber } from "ethers";
import { ethers, network } from "hardhat";
import { getContractArguments } from "../scripts/deploy/helper";

describe("Upgrader Contract", () => {
  let owner: any, addr1: any, company: any, treasury: any;
  let bet: any;
  let blt: any;
  let cs: any;
  let upgrader: any;

  before(async () => {
    [owner, addr1, company, treasury] = await ethers.getSigners();
    // BlastEquipment NFT Deploying
    const BlastEquipmentToken = await ethers.getContractFactory(
      "BlastEquipmentNFT"
    );
    bet = await BlastEquipmentToken.connect(owner).deploy(
      "Blast Equipment",
      "BLT",
      company.address,
      treasury.address
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
      BigNumber.from(secondaryTokenArgs.supply)
    );
    await cs.deployed();
    await (
      await cs
        .connect(owner)
        .transfer(addr1.address, ethers.utils.parseEther("45000"))
    ).wait();

    // Upgrader Contract Deploying
    const upgraderFactory = await ethers.getContractFactory("Upgrader");
    upgrader = await upgraderFactory
      .connect(owner)
      .deploy(
        bet.address,
        blt.address,
        cs.address,
        treasury.address,
        company.address
      );
    await upgrader.deployed();

    // Granting GAME ROLE role to Upgrader contract address
    const GAME_ROLE = await bet.GAME_ROLE();
    await bet.grantRole(GAME_ROLE, upgrader.address);

    // NFT equipment items minting
    const tx = await bet
      .connect(owner)
      .safeMint(
        addr1.address,
        ["ipfs://111", "ipfs://222"],
        [ethers.utils.keccak256("0x1000"), ethers.utils.keccak256("0x2000")],
        ["ipfs://111_real", "ipfs://222_real"]
      );
    await tx.wait();
  });

  it("Upgrade function test", async function () {
    // Approve token
    await (
      await cs
        .connect(addr1)
        .approve(upgrader.address, ethers.utils.parseEther("45000"))
    ).wait();
    await (
      await blt
        .connect(addr1)
        .approve(upgrader.address, ethers.utils.parseEther("14"))
    ).wait();

    const bltPrice = await upgrader.connect(addr1).getRequiredPrice(0, 0);
    const csPrice = await upgrader.connect(addr1).getRequiredPrice(1, 0);
    console.log(bltPrice);
    console.log(csPrice);
  });
});
