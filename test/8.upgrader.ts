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

  // Rarity => [Adjective => Grade => [level => [bltPrice, csPrice]]]
  const EXPECTED_VALUES: any = [
    [
      [
        {
          1: [5.23, 174], // Common, Regular, I, 1
          5: [5.33, 191], // Common, Regular, I, 5
          10: [5.46, 213], // Common, Regular, I, 10
        },
        {},
        {},
        {},
        {
          1: [3, 100], // Common, Regular, V, 1
          5: [3.06, 110], // Common, Regular, V, 5
          10: [3.14, 122], // Common, Regular, V, 10
        },
      ],
    ],
    [
      [
        {
          1: [6.97, 313], // Common, Posh, I, 1
          5: [7.11, 345], // Common, Posh, I, 5
          10: [7.29, 384], // Common, Posh, I, 10
        },
        {},
        {},
        {},
        {
          1: [3, 100], // Common, Regular, V, 1
          5: [3.06, 110], // Common, Regular, V, 5
          10: [3.14, 122], // Common, Regular, V, 10
        },
      ],
    ],
  ];

  const getExpectedValue = async (tokenId: number): Promise<Array<number>> => {
    const _attributes = await bet.getAttributes(tokenId);
    const _staticAttributes = await bet.getStaticAttributes(tokenId);

    const adjective = _staticAttributes[2];
    const rarity = _staticAttributes[3];
    const grade = _staticAttributes[4];
    const level = _attributes[0].toNumber();

    return EXPECTED_VALUES[rarity][adjective][grade][level];
  };

  before(async () => {
    [owner, addr1, company, treasury] = await ethers.getSigners();
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
    const tx = await bet.connect(owner).safeMint(
      addr1.address,
      ["ipfs://111", "ipfs://222"],
      [ethers.utils.keccak256("0x1000"), ethers.utils.keccak256("0x2000")],
      ["ipfs://111_real", "ipfs://222_real"],
      [
        {
          maxLevel: 5,
          maxDurability: 144,
          adjective: 0,
          rarity: 0,
          grade: 4,
        },
        {
          maxLevel: 5,
          maxDurability: 144,
          adjective: 0,
          rarity: 0,
          grade: 4,
        },
      ]
    );
    await tx.wait();
  });

  it("Upgrade function test", async function () {
    const tokenId = 0;
    const BLT_TYPE = 0;
    const CS_TYPE = 1;

    const bltPrice = await upgrader
      .connect(addr1)
      .getRequiredPrice(BLT_TYPE, tokenId);
    const csPrice = await upgrader
      .connect(addr1)
      .getRequiredPrice(CS_TYPE, tokenId);
    const _prices = await getExpectedValue(tokenId);

    expect(bltPrice).to.eq(ethers.utils.parseEther(_prices[0].toString()));
    expect(csPrice).to.eq(ethers.utils.parseEther(_prices[1].toString()));

    // Approve token
    await (
      await cs
        .connect(addr1)
        .approve(upgrader.address, csPrice.sub(BigNumber.from("1")))
    ).wait();

    // Upgrade
    await expect(upgrader.connect(addr1).upgrade(tokenId)).to.revertedWith(
      "ERC20: insufficient allowance"
    );

    await (await cs.connect(addr1).approve(upgrader.address, csPrice)).wait();
    await (await blt.connect(addr1).approve(upgrader.address, bltPrice)).wait();

    await expect(upgrader.connect(addr1).upgrade(tokenId))
      .to.emit(upgrader, "LevelUpgraded")
      .withArgs(tokenId, addr1.address, 2);
  });
});
