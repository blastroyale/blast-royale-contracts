import { expect } from "chai";
import { ethers, network } from "hardhat";

describe("Replicator Contract", function () {
  it("Open function test", async function () {
    const [owner, addr1] = await ethers.getSigners();
    // BlastEquipment NFT Deploying
    const BlastEquipmentToken = await ethers.getContractFactory(
      "BlastEquipmentNFT"
    );
    const bet = await BlastEquipmentToken.connect(owner).deploy(
      "Blast Equipment",
      "BLT"
    );
    await bet.deployed();

    // Blast Token Deploying
    const BlastToken = await ethers.getContractFactory("PrimaryToken");
    const blt = await BlastToken.deploy(
      "Blast Royale",
      "$BLT",
      addr1.address,
      ethers.utils.parseEther("100000000")
    );
    await blt.deployed();

    // CS Token deploying
    const CraftToken = await ethers.getContractFactory("SecondaryToken");
    const cs = await CraftToken.deploy(
      "Craftship",
      "$BLT",
      addr1.address,
      ethers.utils.parseEther("100000000")
    );
    await cs.deployed();

    // Replicator Contract Deploying
    const replicator = await ethers.getContractFactory("Replicator");
    const replicatorContract = await replicator
      .connect(owner)
      .deploy(bet.address, blt.address, cs.address);
    await replicatorContract.deployed();

    // NFT equipment items minting
    const tx = await bet
      .connect(owner)
      .safeMint(
        addr1.address,
        ["ipfs://111", "ipfs://222"],
        [ethers.utils.keccak256("0x1000"), ethers.utils.keccak256("0x2000")],
        ["ipfs://111_real", "ipfs://222_real"]
      );
    await tx.wait();

    // Approve token
    const approveTx1 = await cs
      .connect(addr1)
      .approve(replicatorContract.address, ethers.utils.parseEther("45000"));
    await approveTx1.wait();
    const approveTx2 = await blt
      .connect(addr1)
      .approve(replicatorContract.address, ethers.utils.parseEther("200"));
    await approveTx2.wait();

    // Replicate in Replicator Contract
    const replicateTx = await replicatorContract.connect(addr1).replicate(0, 1);
    await replicateTx.wait();

    // There should be backend logic here after emitting replicated event
    // Will simulate how it works
    // Grant GameRole to addr1
    const GAME_ROLE = await bet.GAME_ROLE();
    await bet.connect(owner).grantRole(GAME_ROLE, addr1.address);

    const eggMetadataUrl =
      "https://flgmarketplacestorage.z33.web.core.windows.net/nftmetadata/replicator/egg_metadata_preview.json";
    const realMetadataUrl =
      "https://flgmarketplacestorage.z33.web.core.windows.net/nftmetadata/0/1/8d7d4991d2fb7363c6bc337665451841cb9374e341b100172fd9cfacd445eb9d.json";
    const hash =
      "0x8d7d4991d2fb7363c6bc337665451841cb9374e341b100172fd9cfacd445eb9d";
    const replicateTxFrom = await bet
      .connect(addr1)
      .replicate(addr1.address, eggMetadataUrl, realMetadataUrl, hash, 0, 1);
    await replicateTxFrom.wait();

    expect(await bet.tokenURI(2)).to.eq(eggMetadataUrl);

    // Time increase to test morphTo function
    await network.provider.send("evm_increaseTime", [3600 * 24 * 5]);
    await network.provider.send("evm_mine");

    // Executing morphTo function
    const morphTx = await bet.connect(addr1).morphTo(2);
    await morphTx.wait();

    expect(await bet.tokenURI(2)).to.eq(realMetadataUrl);
  });
});
