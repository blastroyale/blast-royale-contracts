import { expect } from "chai";
import { ethers } from "hardhat";

describe("Blast Royale Token", function () {
  let owner: any;
  let addr1: any;
  let addr2: any;
  let cs: any;
  before("deploying", async () => {
    const signers = await ethers.getSigners();
    [owner, addr1, addr2] = signers;
  });
  it("Test Secondary Token", async function () {
    const CraftToken = await ethers.getContractFactory("SecondaryToken");
    cs = await CraftToken.deploy(
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

  it("Test role accessibility", async function () {
    // only MINTER_ROLE role can claim
    await expect(
      cs.connect(addr1).claim(addr1.address, ethers.utils.parseEther("100"))
    ).to.be.reverted;
  });

  it("Pause the contract", async function () {
    // only ADMIN_ROLE role can pause
    await expect(cs.connect(addr1).pause()).to.be.reverted;

    await cs.connect(owner).pause();

    await expect(
      cs.connect(owner).transfer(addr1.address, ethers.utils.parseEther("100"))
    ).to.be.reverted;
  });

  it("Unpause the contract", async function () {
    // only ADMIN_ROLE role can unpause
    await expect(cs.connect(addr1).unpause()).to.be.reverted;

    await cs.connect(owner).unpause();

    expect(
      await cs
        .connect(owner)
        .transfer(addr1.address, ethers.utils.parseEther("100"))
    );
    // can transfer balance when it's unpaused
    expect(await cs.balanceOf(addr1.address)).to.equal(
      ethers.utils.parseEther("200")
    );
  });
});
