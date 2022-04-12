import { ethers } from "hardhat";

const defaultName = "Blast NFT";
const defaultSymbol = "BNFT";
const uri1 = "https://blastroyale.com/nft/building.png";
const uri2 = "https://blastroyale.com/nft/crafting.png";

interface IBlast {
  owner: any;
  minter: any;
  game: any;
  treasury: any;
  treasury2: any;
  player1: any;
  player2: any;
  blt?: any;
  cs?: any;
  equipment?: any;
  factory?: any;
  market?: any;
  MINTER_ROLE?: string;
  GAME_ROLE?: string;
}
async function deployTokens(blast: IBlast) {
  const BlastToken = await ethers.getContractFactory("BlastRoyaleToken");
  blast.blt = await BlastToken.deploy(
    "Blast Royale Token",
    "$BLT",
    blast.owner.address,
    ethers.utils.parseEther("100000000")
  );
  await blast.blt.deployed();
  await blast.blt
    .connect(blast.owner)
    .transfer(blast.player1.address, ethers.utils.parseUnits("1000"));
  await blast.blt
    .connect(blast.owner)
    .transfer(blast.player2.address, ethers.utils.parseUnits("2000"));

  const CraftshipToken = await ethers.getContractFactory("CraftshipToken");
  blast.cs = await CraftshipToken.deploy(
    "Craftship",
    "$CS",
    blast.owner.address,
    ethers.utils.parseEther("100000000")
  );
  await blast.cs.deployed();
  await blast.cs
    .connect(blast.owner)
    .transfer(blast.player1.address, ethers.utils.parseUnits("1000"));
  await blast.cs
    .connect(blast.owner)
    .transfer(blast.player2.address, ethers.utils.parseUnits("2000"));
}

async function deployEquipmentNFT(blast: IBlast) {
  const BlastEquipmentNFT = await ethers.getContractFactory(
    "BlastEquipmentNFT"
  );
  blast.equipment = await BlastEquipmentNFT.connect(blast.minter).deploy(
    defaultName,
    defaultSymbol,
    blast.minter.address,
    blast.game.address
  );
  await blast.equipment.deployed();
  blast.MINTER_ROLE = await blast.equipment.MINTER_ROLE();
  blast.GAME_ROLE = await blast.equipment.GAME_ROLE();
}

async function deployFactory(blast: IBlast) {
  const BlastFactory = await ethers.getContractFactory("BlastFactory");
  blast.factory = await BlastFactory.connect(blast.owner).deploy(
    blast.equipment.address,
    blast.blt.address,
    blast.cs.address,
    blast.treasury.address,
    uri2
  );
  await blast.factory.deployed();

  // Set Prices.
  await blast.factory.setPrices(
    ethers.utils.parseUnits("2"),
    ethers.utils.parseUnits("10"),
    ethers.utils.parseUnits("5"),
    ethers.utils.parseUnits("15")
  );

  // Factory Needs MINTER ROLE (Craft new Items) and GAME (Repair -> set attributes).
  await blast.equipment.grantRole(blast.MINTER_ROLE, blast.factory.address);
  await blast.equipment.grantRole(blast.GAME_ROLE, blast.factory.address);
  await blast.cs.grantRole(blast.GAME_ROLE, blast.factory.address);
}

async function setup(): Promise<IBlast> {
  const wallets = await ethers.getSigners();
  const blast: IBlast = {
    owner: wallets[0],
    minter: wallets[1],
    game: wallets[2],
    treasury: wallets[3],
    treasury2: wallets[4],
    player1: wallets[5],
    player2: wallets[6],
  };

  // Deploy Tokens : BLT & CS
  await deployTokens(blast);

  // Deploy EquipmentNFT & Mint a few
  await deployEquipmentNFT(blast);
  await blast.equipment
    .connect(blast.minter)
    .safeMint(10, blast.player1.address, uri1);
  await blast.equipment
    .connect(blast.game)
    .setTokenURI([0, 1, 2], ["otherURI1", "otherURI2", "otherURI3"]);

  // Deploy Factory.
  await deployFactory(blast);
  return blast;
}

async function getBalance(token: any, addr: string): Promise<number> {
  const balance = ethers.utils.formatUnits(await token.balanceOf(addr), 18);
  return parseInt(balance);
}

export { setup, IBlast, getBalance };
