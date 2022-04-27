import { expect } from "chai";
import { ethers } from "hardhat";
// import * as ethSigUtil from "eth-sig-util";

describe("Blast Royale Token", function () {
  it("Test Primary Token", async function () {
    const [owner, addr1, addr2] = await ethers.getSigners();
    const BlastToken = await ethers.getContractFactory("PrimaryToken");
    const blt = await BlastToken.deploy(
      "Blast Royale",
      "$BLT",
      owner.address,
      ethers.utils.parseEther("100000000")
    );
    await blt.deployed();

    let tx = await blt.mint(addr1.address, ethers.utils.parseEther("100"));
    await tx.wait();
    tx = await blt.mint(addr2.address, ethers.utils.parseEther("500"));
    await tx.wait();

    expect(await blt.balanceOf(addr1.address)).to.equal(
      ethers.utils.parseEther("100")
    );
  });
});
