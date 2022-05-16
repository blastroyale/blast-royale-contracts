import { expect } from "chai";
import { ethers } from "hardhat";

describe("Blast Royale Token", function () {
  it("Test Secondary Token", async function () {
    const [owner, addr1, addr2] = await ethers.getSigners();
    const CraftToken = await ethers.getContractFactory("SecondaryToken");
    const cs = await CraftToken.deploy(
      "Craftship",
      "$CS",
      ethers.utils.parseEther("100000000")
    );
    await cs.deployed();

    let tx = await cs
      .connect(owner)
      .claim(addr1.address, ethers.utils.parseEther("100"));
    await tx.wait();

    tx = await cs
      .connect(owner)
      .claim(addr2.address, ethers.utils.parseEther("500"));
    await tx.wait();

    expect(await cs.balanceOf(addr2.address)).to.equal(
      ethers.utils.parseEther("500")
    );

    expect(await cs.balanceOf(addr1.address)).to.equal(
      ethers.utils.parseEther("100")
    );
  });
});
