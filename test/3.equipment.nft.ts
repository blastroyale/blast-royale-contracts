import { expect } from "chai";
import { ethers } from "hardhat";

describe("Blast Equipment NFT", function () {
  let owner: any;
  let treasury: any;
  let addr1: any;
  let blt: any;
  let blst: any;
  let cs: any;

  before(async () => {
    [owner, treasury, addr1] = await ethers.getSigners();
    const CraftToken = await ethers.getContractFactory("SecondaryToken");
    cs = await CraftToken.deploy(
      "Craftship",
      "$CS",
      ethers.utils.parseEther("100000000"),
      owner.address
    );
    await cs.deployed();
    await cs
      .connect(owner)
      .claim(addr1.address, ethers.utils.parseEther("10000"));

    const BlastToken = await ethers.getContractFactory("PrimaryToken");
    blst = await BlastToken.deploy(
      "Blast Royale",
      "$BLT",
      owner.address,
      treasury.address,
      ethers.utils.parseEther("512000000")
    );
    await blst.deployed();
    await blst
      .connect(treasury)
      .transfer(addr1.address, ethers.utils.parseEther("10000000"));

    const BlastEquipmentToken = await ethers.getContractFactory(
      "BlastEquipmentNFT"
    );
    blt = await BlastEquipmentToken.connect(owner).deploy(
      "Blast Equipment",
      "BLT"
    );
    await blt.deployed();

    const tx = await blt.connect(owner).safeMint(
      addr1.address,
      ["ipfs://111", "ipfs://222"],
      [ethers.utils.keccak256("0x1000"), ethers.utils.keccak256("0x2000")],
      ["ipfs://111_real", "ipfs://222_real"],
      [
        [5, 0, 0, 0, 0],
        [1, 0, 0, 0, 0],
      ]
    );
    await tx.wait();
  });

  it("Test NFT", async () => {
    await blt.connect(owner).setLevel(0, 3);
    await blt.connect(owner).setRepairCount(0, 1);
    await blt.connect(owner).setReplicationCount(0, 4);

    expect(await blt.balanceOf(addr1.address)).to.equal(2);
    expect(await blt.tokenURI(0)).to.equal("ipfs://111");
    expect(await blt.tokenURI(1)).to.equal("ipfs://222");
    expect(await blt.hashValue(0)).to.equal(ethers.utils.keccak256("0x1000"));

    const nftAttributes = await blt.getAttributes(0);
    const level = nftAttributes[0].toNumber();
    const durabilityRemaining = nftAttributes[1].toNumber();
    const repairCount = nftAttributes[4].toNumber();
    const replicationCount = nftAttributes[5].toNumber();

    expect(level).to.equal(3);
    expect(durabilityRemaining).to.equal(0);
    expect(repairCount).to.equal(1);
    expect(replicationCount).to.equal(4);
  });
});
