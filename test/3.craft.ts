import { expect } from "chai";
import { ethers } from "hardhat";

const defaultName = "Blast NFT";
const defaultSymbol = "BNFT";
const defaultBLTName = "Blast Token";
const defaultBLTSymbol = "BNFT";

const uri1 = "https://blastroyale.com/nft/building.png";
const uric = "https://blastroyale.com/nft/crafting.png";

describe("Blast Equipment NFT", function () {
  let minter: any, game: any, treasury: any, player1: any;
  let bnft: any, blt: any, craft: any;

  before("deploying", async () => {
    [minter, game, treasury, player1] = await ethers.getSigners();
  });

  it("Deploy NFT", async () => {
    // Deplot The EquipmentNFT Contract.
    const BlastEquipmentToken = await ethers.getContractFactory("EquipmentNFT");
    bnft = await BlastEquipmentToken.connect(minter).deploy(
      defaultName,
      defaultSymbol,
      minter.address,
      game.address
    );
    await bnft.deployed();
    await bnft.connect(minter).safeMint(2, player1.address, uri1);
    await bnft.connect(game).setTokenURI([0, 1], ["otherURI1", "otherURI2"]);

    // Deploy the BLT Primary Token.
    const PrimaryToken = await ethers.getContractFactory("PrimaryToken");
    blt = await PrimaryToken.connect(minter).deploy(
      defaultBLTName,
      defaultBLTSymbol,
      minter.address,
      ethers.utils.parseUnits("100000")
    );
    await blt
      .connect(minter)
      .transfer(player1.address, ethers.utils.parseUnits("100"));

    // Deploy the CraftNFT contract. Set the Equipment NFT address and the BLT Token address.
    const CraftNFT = await ethers.getContractFactory("CraftNFT");
    craft = await CraftNFT.connect(minter).deploy(
      bnft.address,
      blt.address,
      treasury.address,
      ethers.utils.parseUnits("10"),
      uric
    );

    // Give CraftNFT contract the ROLE of GAME and MINTER in the Equipment Contract.
    await bnft.connect(minter).grantRole(await bnft.GAME_ROLE(), craft.address);
    await bnft
      .connect(minter)
      .grantRole(await bnft.MINTER_ROLE(), craft.address);
  });

  it("Craft a new NFT", async () => {
    await blt
      .connect(player1)
      .approve(craft.address, ethers.utils.parseUnits("10"));
    await craft.connect(player1).craft(0, 1);
    expect(await bnft.tokenURI(2)).to.equal(uric);
  });

  it("Cannot repair NFT", async () => {
    await bnft.connect(player1).repair(0);
  });
});
