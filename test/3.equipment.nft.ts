import { expect } from "chai";
import { ethers } from "hardhat";

const defaultName = "Blast NFT";
const defaultSymbol = "BNFT";
const uri1 = "https://blastroyale.com/nft/building.png";
const ZERO_ADDRESS = "0x0000000000000000000000000000000000000000";

describe("3 - Blast Equipment NFT Minting From a Wallet", function () {
  let minter: any, game: any, player1: any;
  let bnft: any;

  before("deploying", async () => {
    [minter, game, player1] = await ethers.getSigners();
  });

  it("Deploy NFT", async () => {
    // Deploy EquipmentNFT
    const BlastEquipmentNFT = await ethers.getContractFactory(
      "BlastEquipmentNFT"
    );
    bnft = await BlastEquipmentNFT.connect(minter).deploy(
      defaultName,
      defaultSymbol,
      minter.address,
      game.address
    );
    await bnft.deployed();
    expect(await bnft.name()).to.equal(defaultName);
    expect(await bnft.symbol()).to.equal(defaultSymbol);
  });

  it("Mint NFTs", async () => {
    await expect(bnft.connect(minter).safeMint(10, player1.address, uri1))
      .to.emit(bnft, "Transfer")
      .withArgs(ZERO_ADDRESS, player1.address, 1)
      .to.emit(bnft, "Transfer")
      .withArgs(ZERO_ADDRESS, player1.address, 2);

    expect(await bnft.balanceOf(player1.address)).to.equal(10);
    expect(await bnft.tokenURI(1)).to.equal(uri1);
    expect(await bnft.tokenURI(2)).to.equal(uri1);
  });

  it("Change URIs", async () => {
    await expect(
      bnft.connect(minter).setTokenURI([1], ["newuri1"])
    ).to.be.revertedWith(
      "AccessControl: account 0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266 is missing role 0x6a64baf327d646d1bca72653e2a075d15fd6ac6d8cbd7f6ee03fc55875e0fa88"
    );
    await bnft.connect(game).setTokenURI([1, 2], ["otherURI1", "otherURI2"]);
    await expect(
      bnft.connect(game).setTokenURI([1, 2], ["otherURI1", "otherURI2"])
    ).to.be.revertedWith("URI Can only be set once");
  });
});
