import { expect } from "chai";
import { ethers } from "hardhat";

const defaultName = "Blast NFT";
const defaultSymbol = "BNFT";
const uri1 = "https://blastroyale.com/nft/building.png";

describe("Blast Equipment NFT", function () {
  let minter: any, game: any, player1: any;
  let bnft: any;

  before("deploying", async () => {
    [minter, game, player1] = await ethers.getSigners();
  });

  it("Deploy NFT", async () => {
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
  });

  it("Repair NFT", async () => {
    let repairCount = await bnft.attributes(0, 3);
    const repairTS1 = await bnft.attributes(0, 4);
    expect(repairCount).to.equal(0);
    await bnft.connect(player1).repair(0);
    repairCount = await bnft.attributes(0, 3);
    expect(repairCount).to.equal(1);
    const repairTS2 = await bnft.attributes(0, 4);
    expect(repairTS2 > repairTS1).to.be.true;
  });

  it("Cannot repair NFT", async () => {
    await expect(bnft.connect(game).repair(0)).to.be.revertedWith(
      "Only the owner can repair"
    );
  });

  it("Fails to repair NFT", async () => {
    await bnft.connect(player1).repair(0);
    await bnft.connect(player1).repair(0);
    await bnft.connect(player1).repair(0);
    await bnft.connect(player1).repair(0);
    await expect(bnft.connect(player1).repair(0)).to.be.revertedWith(
      "Max repair reached"
    );
  });
});
