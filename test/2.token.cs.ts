import { expect } from "chai";
import { ethers } from "hardhat";
import { signCall } from "./utils/setup";

describe("2 - Blast Royale Secondary Token : Craftship ($CS)", function () {
  it("Deploy and Mint $CS", async function () {
    const [owner, game, addr1, addr2] = await ethers.getSigners();
    const CraftshipToken = await ethers.getContractFactory("CraftshipToken");

    // Deploy $CS.
    // - Name of the Contract : Blast Royale Token
    // - Symbol of the Contract: BLT
    // - Address of the owner of the contract
    // - Initial Supply (goes to the owner)
    const cs = await CraftshipToken.deploy(
      "Craftship",
      "$BLT",
      owner.address,
      ethers.utils.parseEther("100000000")
    );
    await cs.deployed();
    await cs.grantRole(await cs.GAME_ROLE(), game.address);

    // Prepare the Domain (EIP712) to sign mintings.
    const domain = {
      name: "Craftship",
      version: "1",
      chainId: await cs.getChainId(),
      verifyingContract: cs.address,
    };

    // Get the nonce (different for every address to avoid conflicts).
    let nonce = await cs.nonce(addr1.address);

    // Sign the new minting : address to, number of lootboxes, nonce
    let signature = await signCall(
      // Domain of the signature
      domain,
      // Address receiveing the Tokens
      addr1.address,
      // Amount
      "100",
      // Signer.
      game,
      // Actual Nonce for the address receiving.
      nonce
    );

    let tx = await cs
      .connect(addr1)
      .mint(ethers.utils.parseEther("100"), signature);
    await tx.wait();

    // Mint for a different address.
    nonce = await cs.nonce(addr2.address);
    signature = await signCall(domain, addr2.address, "500", game, nonce);
    tx = await cs
      .connect(addr2)
      .mint(ethers.utils.parseEther("500"), signature);
    await tx.wait();

    // Check Balance.
    expect(await cs.balanceOf(addr2.address)).to.equal(
      ethers.utils.parseEther("500")
    );
  });
});
