import { expect } from "chai";
import { ethers } from "hardhat";

async function signCall(
  domain: any,
  minter: string,
  amount: string,
  signer: any,
  nonce: any
) {
  const types = {
    Call: [
      { name: "minter", type: "address" },
      { name: "amount", type: "uint256" },
      { name: "nonce", type: "uint256" },
    ],
  };
  const value = {
    minter,
    amount: ethers.utils.parseEther(amount),
    nonce,
  };
  const signature = signer._signTypedData(domain, types, value);
  return signature;
}

describe("Blast Royale Token", function () {
  it("Test Secondary Token", async function () {
    const [owner, addr1, addr2] = await ethers.getSigners();
    const CraftToken = await ethers.getContractFactory("SecondaryToken");
    const cs = await CraftToken.deploy(
      "Craftship",
      "$BLT",
      owner.address,
      ethers.utils.parseEther("100000000")
    );
    await cs.deployed();

    const domain = {
      name: "Craftship",
      version: "1",
      chainId: await cs.getChainId(),
      verifyingContract: cs.address,
    };
    let nonce = await cs.nonce();
    let signature = await signCall(domain, addr1.address, "100", owner, nonce);

    let tx = await cs
      .connect(addr1)
      .mint(ethers.utils.parseEther("100"), signature);
    await tx.wait();

    nonce = await cs.nonce();
    signature = await signCall(domain, addr2.address, "500", owner, nonce);
    tx = await cs
      .connect(addr2)
      .mint(ethers.utils.parseEther("500"), signature);
    await tx.wait();

    expect(await cs.balanceOf(addr2.address)).to.equal(
      ethers.utils.parseEther("500")
    );
  });
});
