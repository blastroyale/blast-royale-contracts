import { expect } from "chai";
import { ethers } from "hardhat";

describe("Blast Royale Token", function () {
  it("Test Primary Token", async function () {
    const [owner] = await ethers.getSigners();
    const BlastToken = await ethers.getContractFactory("PrimaryToken");
    const blt = await BlastToken.deploy(
      "Blast Royale",
      "$BLT",
      ethers.utils.parseEther("512000000")
    );
    await blt.deployed();

    expect(await blt.balanceOf(owner.address)).to.equal(
      ethers.utils.parseEther("512000000")
    );
  });
});
