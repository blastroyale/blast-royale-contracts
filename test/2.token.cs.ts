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
    "Call": [
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

describe("Blast Royale Secondary Token : Craftship ($CS)", function () {
  it("Deploy and Mint $CS", async function () {
    const [owner, game, addr1, addr2] = await ethers.getSigners();

    // Deploy $CS.
    const CraftshipToken = await ethers.getContractFactory("CraftshipToken");
    const cs = await CraftshipToken.deploy(
      "Craftship",
      "$BLT",
      owner.address,
      ethers.utils.parseEther("100000000")
    );
    await cs.deployed();
    await cs.grantRole(await cs.GAME_ROLE(), game.address);

    // Sign and Mint Tokens.
    const domain = {
      name: "Craftship",
      version: "1",
      chainId: await cs.getChainId(),
      verifyingContract: cs.address,
    };
    let nonce = await cs.nonce(addr1.address);
    let signature = await signCall(domain, addr1.address, "100", game, nonce);

    let tx = await cs
      .connect(addr1)
      .mint(ethers.utils.parseEther("100"), signature);
    await tx.wait();

    nonce = await cs.nonce(addr2.address);
    signature = await signCall(domain, addr2.address, "500", game, nonce);
    tx = await cs
      .connect(addr2)
      .mint(ethers.utils.parseEther("500"), signature);
    await tx.wait();

    expect(await cs.balanceOf(addr2.address)).to.equal(
      ethers.utils.parseEther("500")
    );
  });
});
