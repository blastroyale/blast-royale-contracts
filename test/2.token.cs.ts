import { expect } from "chai";
import { providers } from "ethers";
import { ethers } from "hardhat";

describe("Blast Royale Token", function () {
  let owner: any;
  let addr1: any;
  let addr2: any;
  let adminPrivate: any;
  let cs: any;
  before("deploying", async () => {
    const signers = await ethers.getSigners();
    [owner, addr1, addr2, adminPrivate] = signers;
  });

  it("Test Secondary Token", async function () {
    const CraftToken = await ethers.getContractFactory("SecondaryToken");
    cs = await CraftToken.deploy(
      "Craftship",
      "$CS",
      ethers.utils.parseEther("100000000"),
      adminPrivate.address
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

    await cs.connect(owner).pause();;

    await expect(
      cs.connect(owner).transfer(addr1.address, ethers.utils.parseEther("100"))
    ).to.be.reverted;
  });

  it("Unpause the contract", async function () {
    // only ADMIN_ROLE role can unpause
    await expect(cs.connect(addr1).unpause()).to.be.reverted;

    await cs.connect(owner).unpause();;

    expect(
      await cs
          .connect(owner)
          .transfer(addr1.address, ethers.utils.parseEther("100"))
    );;
    // can transfer balance when it's unpaused
    expect(await cs.balanceOf(addr1.address)).to.equal(
      ethers.utils.parseEther("200")
    );
  });

  it("Self Claiming Test", async function () {
    const block = await providers.getDefaultProvider().getBlock("latest");
    const blockTimestamp = block.timestamp;
    const deadline = blockTimestamp + 3600;
    const nonce = await cs.nonces(addr2.address);

    const claimMessageHash = ethers.utils.solidityKeccak256(
      ["address", "uint256", "uint256", "uint256"],
      [addr2.address, ethers.utils.parseEther("1"), nonce, deadline]
    );
    const signature = await adminPrivate.signMessage(
      ethers.utils.arrayify(claimMessageHash)
    );

    // In case call is not the user who is able to claim CS token
    await expect(
      cs
        .connect(addr1)
        .claimSelf(ethers.utils.parseEther("1"), deadline, signature)
    ).to.revertedWith("CS:Invalid Signature in claiming");

    // Deadline is expired
    await expect(
      cs
        .connect(addr1)
        .claimSelf(ethers.utils.parseEther("1"), deadline - 3900, signature)
    ).to.revertedWith("CS:Signature expired");

    // User is trying to call the another amount of CS token
    await expect(
      cs
        .connect(addr2)
        .claimSelf(ethers.utils.parseEther("2"), deadline, signature)
    ).to.revertedWith("CS:Invalid Signature in claiming");

    const prevBalance = await cs.balanceOf(addr2.address);
    await expect(
      cs
        .connect(addr2)
        .claimSelf(ethers.utils.parseEther("1"), deadline, signature)
    )
      .to.emit(cs, "Transfer")
      .withArgs(
        ethers.constants.AddressZero,
        addr2.address,
        ethers.utils.parseEther("1")
      );

    expect(await cs.balanceOf(addr2.address)).to.equal(
      prevBalance.add(ethers.utils.parseEther("1"))
    );
  });
});
