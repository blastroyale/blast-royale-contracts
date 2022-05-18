import { expect } from "chai";
import { ethers, network } from "hardhat";

describe("Replicator Contract", function () {
  it("Replicate function test", async function () {
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
      ethers.utils.parseEther("100000000")
    );
    await blt.deployed();
    await (
      await blt.transfer(addr1.address, ethers.utils.parseEther("200"))
    ).wait();

    // CS Token deploying
    const CraftToken = await ethers.getContractFactory("SecondaryToken");
    const cs = await CraftToken.deploy(
      "Craftship",
      "$BLT",
      ethers.utils.parseEther("100000000")
    );
    await cs.deployed();
    await (
      await cs.transfer(addr1.address, ethers.utils.parseEther("45000"))
    ).wait();

    // Replicator Contract Deploying
    const replicator = await ethers.getContractFactory("Replicator");
    const replicatorContract = await replicator
      .connect(owner)
      .deploy(bet.address, blt.address, cs.address);
    await replicatorContract.deployed();

    // Granting Replicator role to replicator contract address
    const REPLICATOR_ROLE = await bet.REPLICATOR_ROLE();
    await bet.grantRole(REPLICATOR_ROLE, replicatorContract.address);

    // Granting Replicator role to replicator contract address
    const REVEAL_ROLE = await bet.REVEAL_ROLE();
    await bet.grantRole(REVEAL_ROLE, replicatorContract.address);

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

    const eggMetadataUrl =
      "https://flgmarketplacestorage.z33.web.core.windows.net/nftmetadata/replicator/egg_metadata_preview.json";
    const realMetadataUrl =
      "https://flgmarketplacestorage.z33.web.core.windows.net/nftmetadata/0/1/8d7d4991d2fb7363c6bc337665451841cb9374e341b100172fd9cfacd445eb9d.json";
    const hash =
      "0x8d7d4991d2fb7363c6bc337665451841cb9374e341b100172fd9cfacd445eb9d";
    // Replicate in Replicator Contract
    await (
      await replicatorContract
        .connect(addr1)
        .replicate(eggMetadataUrl, hash, realMetadataUrl, 0, 1)
    ).wait();

    // There should be backend logic here after emitting replicated event
    // Will simulate how it works

    // const replicateTxFrom = await bet
    //   .connect(addr1)
    //   .replicate(0, 1);
    // await replicateTxFrom.wait();

    expect(await bet.tokenURI(2)).to.eq(eggMetadataUrl);

    // Time increase to test morphTo function
    await network.provider.send("evm_increaseTime", [3600 * 24 * 6]);
    await network.provider.send("evm_mine");

    // Executing morphTo function
    const morphTx = await replicatorContract.connect(addr1).morph(2);
    await morphTx.wait();

    expect(await bet.tokenURI(2)).to.eq(realMetadataUrl);
  });
});
