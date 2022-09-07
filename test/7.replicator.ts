/* eslint-disable node/no-missing-import */
import { expect } from "chai";
import { BigNumber, providers } from "ethers";
import { ethers, network } from "hardhat";
import { getContractArguments } from "../scripts/deploy/helper";

describe("Replicator Contract", () => {
  it("Replicate function test", async function () {
    const [owner, addr1, company, treasury] = await ethers.getSigners();
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
    const primaryTokenArgs = getContractArguments(network.name, "PrimaryToken");
    const BlastToken = await ethers.getContractFactory("PrimaryToken");
    const blt = await BlastToken.deploy(
      primaryTokenArgs.name,
      primaryTokenArgs.symbol,
      owner.address, // owner address
      owner.address, // treasury address
      BigNumber.from(primaryTokenArgs.supply) // fixed supply 512M
    );
    await blt.deployed();
    await (
      await blt
        .connect(owner)
        .transfer(addr1.address, ethers.utils.parseEther("200"))
    ).wait();

    // CS Token deploying
    const secondaryTokenArgs = getContractArguments(
      network.name,
      "SecondaryToken"
    );
    const CraftToken = await ethers.getContractFactory("SecondaryToken");
    const cs = await CraftToken.deploy(
      secondaryTokenArgs.name,
      secondaryTokenArgs.symbol,
      BigNumber.from(secondaryTokenArgs.supply),
      owner.address
    );
    await cs.deployed();
    await (
      await cs
        .connect(owner)
        .transfer(addr1.address, ethers.utils.parseEther("45000"))
    ).wait();

    // Replicator Contract Deploying
    const replicator = await ethers.getContractFactory("Replicator");
    const replicatorContract = await replicator
      .connect(owner)
      .deploy(
        bet.address,
        blt.address,
        cs.address,
        treasury.address,
        company.address,
        owner.address
      );
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
      .approve(replicatorContract.address, ethers.utils.parseEther("14"));
    await approveTx2.wait();

    const eggMetadataUrl =
      "https://flgmarketplacestorage.z33.web.core.windows.net/nftmetadata/replicator/egg_metadata_preview.json";
    const realMetadataUrl =
      "https://flgmarketplacestorage.z33.web.core.windows.net/nftmetadata/0/1/8d7d4991d2fb7363c6bc337665451841cb9374e341b100172fd9cfacd445eb9d.json";
    const hash =
      "0x8d7d4991d2fb7363c6bc337665451841cb9374e341b100172fd9cfacd445eb9d";

    await (
      await bet.connect(addr1).approve(replicatorContract.address, 0)
    ).wait();
    await (
      await bet.connect(addr1).approve(replicatorContract.address, 1)
    ).wait();

    // Signature generation with EIP712
    const block = await providers.getDefaultProvider().getBlock("latest");
    const blockTimestamp = block.timestamp;
    const deadline = blockTimestamp + 3600;
    const nonce = await replicatorContract.nonces(addr1.address);

    const signature = await owner._signTypedData(
      // Domain
      {
        name: "REPLICATOR",
        version: "1.0.0",
        chainId: 31337,
        verifyingContract: replicatorContract.address,
      },
      // Types
      {
        REPLICATOR: [
          { name: "sender", type: "address" },
          { name: "uri", type: "string" },
          { name: "hash", type: "bytes32" },
          { name: "realUri", type: "string" },
          { name: "p1", type: "uint256" },
          { name: "p2", type: "uint256" },
          { name: "nonce", type: "uint256" },
          { name: "deadline", type: "uint256" },
        ],
      },
      // Value
      {
        sender: addr1.address,
        uri: eggMetadataUrl,
        hash: hash,
        realUri: realMetadataUrl,
        p1: 0,
        p2: 1,
        nonce: nonce.toNumber(),
        deadline: deadline,
      }
    );

    // Replicate in Replicator Contract
    await expect(
      replicatorContract
        .connect(addr1)
        .replicate(
          eggMetadataUrl + "123",
          hash,
          realMetadataUrl,
          0,
          1,
          deadline,
          signature
        )
    ).revertedWith("Replicator:Invalid Signature");
    await expect(
      replicatorContract
        .connect(addr1)
        .replicate(
          eggMetadataUrl,
          hash,
          realMetadataUrl + "1",
          0,
          1,
          deadline,
          signature
        )
    ).revertedWith("Replicator:Invalid Signature");

    // Expecting event emitted
    await expect(
      replicatorContract
        .connect(addr1)
        .replicate(
          eggMetadataUrl,
          hash,
          realMetadataUrl,
          0,
          1,
          deadline,
          signature
        )
    ).to.emit(replicatorContract, "Replicated");

    // There should be backend logic here after emitting replicated event
    // Will simulate how it works

    // const replicateTxFrom = await bet
    //   .connect(addr1)
    //   .replicate(0, 1);
    // await replicateTxFrom.wait();

    expect(await blt.balanceOf(company.address)).to.eq(
      ethers.utils.parseEther("10.5")
    );
    expect(await blt.balanceOf(treasury.address)).to.eq(
      ethers.utils.parseEther("3.5")
    );

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
