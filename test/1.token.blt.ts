import { expect } from "chai";
import { ethers } from "hardhat";

describe("1 - Blast Royale Primary Token : BLT", function () {
  it("Deploy and Mint BLT", async function () {
    const [owner, addr1, addr2] = await ethers.getSigners();
    const BlastToken = await ethers.getContractFactory("BlastRoyaleToken");

    // Deploy BLT.
    // - Name of the Contract : Blast Royale Token
    // - Symbol of the Contract: BLT
    // - Address of the owner of the contract
    // - Initial Supply (goes to the owner)
    const blt = await BlastToken.deploy(
      "Blast Royale Token",
      "BLT",
      owner.address,
      ethers.utils.parseEther("100000000")
    );
    await blt.deployed();

    // Mintinig (onlyOwner) : address and amount
    let tx = await blt.mint(addr1.address, ethers.utils.parseEther("100"));
    await tx.wait();
    tx = await blt.mint(addr2.address, ethers.utils.parseEther("500"));
    await tx.wait();

    // Check Balance.
    expect(await blt.balanceOf(addr1.address)).to.equal(
      ethers.utils.parseEther("100")
    );
    expect(await blt.balanceOf(addr2.address)).to.equal(
      ethers.utils.parseEther("500")
    );
  });
});
