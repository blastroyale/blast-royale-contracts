import { expect } from "chai";
import { Signer } from "ethers";
import { ethers } from "hardhat";
import { MerkleTree } from "merkletreejs";

describe("Blast Royale Marketplace Lootbox", function () {
  let blt: any;
  let nft: any;
  let lootbox: any;
  let lootboxSale: any;
  let admin: any;
  let player1: any;
  let player2: any;
  let player3: any;
  let treasury: any;
  let whitelisted: Signer[];
  let notWhitelisted: Signer[];
  let tree: any;

  before("deploying", async () => {
    const signers = await ethers.getSigners();
    admin = signers[0];
    player1 = signers[1];
    player2 = signers[2];
    player3 = signers[3];
    treasury = signers[9];

    whitelisted = signers.slice(0, 5);
    notWhitelisted = signers.slice(5, 10);
  });

  it("Deploy Primary Token", async function () {
    const BlastToken = await ethers.getContractFactory("PrimaryToken");
    blt = await BlastToken.deploy(
      "Blast Royale",
      "$BLT",
      admin.address,
      treasury.address,
      ethers.utils.parseEther("512000000") // fixed supply 512M
    );
    await blt.deployed();
    await blt
      .connect(treasury)
      .transfer(player1.address, ethers.utils.parseUnits("1000"));
    await blt
      .connect(treasury)
      .transfer(player2.address, ethers.utils.parseUnits("1000"));
    await blt
      .connect(treasury)
      .transfer(player3.address, ethers.utils.parseUnits("1000"));
  });

  it("Deploy NFT", async function () {
    const BlastNFT = await ethers.getContractFactory("BlastEquipmentNFT");
    nft = await BlastNFT.connect(admin).deploy("Blast Royale", "$BLT");
    await nft.deployed();
  });

  it("Deploy Lootbox", async () => {
    const BlastLootBox = await ethers.getContractFactory("BlastLootBox");
    lootbox = await BlastLootBox.connect(admin).deploy(
      "Lootbox",
      "$BLB",
      nft.address
    );
    await lootbox.deployed();

    // Equipment NFT mint to blast Lootbox contract
    await (
      await nft
        .connect(admin)
        .safeMint(
          lootbox.address,
          [
            "ipfs://111",
            "ipfs://222",
            "ipfs://333",
            "ipfs://111",
            "ipfs://222",
            "ipfs://333",
            "ipfs://111",
            "ipfs://222",
            "ipfs://333",
          ],
          [
            ethers.utils.keccak256("0x1000"),
            ethers.utils.keccak256("0x2000"),
            ethers.utils.keccak256("0x3000"),
            ethers.utils.keccak256("0x1000"),
            ethers.utils.keccak256("0x2000"),
            ethers.utils.keccak256("0x3000"),
            ethers.utils.keccak256("0x1000"),
            ethers.utils.keccak256("0x2000"),
            ethers.utils.keccak256("0x3000"),
          ],
          [
            "ipfs://111_real",
            "ipfs://222_real",
            "ipfs://333_real",
            "ipfs://111_real",
            "ipfs://222_real",
            "ipfs://333_real",
            "ipfs://111_real",
            "ipfs://222_real",
            "ipfs://333_real",
          ]
        )
    ).wait();

    // Lootbox SafeMint
    await (
      await lootbox.connect(admin).safeMint(
        [admin.address, admin.address],
        ["ipfs://lootbox_111", "ipfs://lootbox_333"],
        [
          {
            token0: 0,
            token1: 1,
            token2: 2,
          },
          {
            token0: 6,
            token1: 7,
            token2: 8,
          },
        ],
        1
      )
    ).wait();

    await (
      await lootbox.connect(admin).safeMint(
        [admin.address],
        ["ipfs://lootbox_222"],
        [
          {
            token0: 3,
            token1: 4,
            token2: 5,
          },
        ],
        2
      )
    ).wait();
  });

  it("Deploy Marketplace", async function () {
    const leaves = await Promise.all(
      whitelisted.map(async (account) => {
        const address = await account.getAddress();
        return ethers.utils.keccak256(address);
      })
    );
    tree = new MerkleTree(leaves, ethers.utils.keccak256, {
      sortPairs: true,
    });
    // const merkleRoot = ethers.utils.formatBytes32String("");
    const merkleRoot = tree.getHexRoot();
    console.log(merkleRoot);

    const lootboxSaleContract = await ethers.getContractFactory(
      "BlastLootboxSale"
    );
    lootboxSale = await lootboxSaleContract
      .connect(admin)
      .deploy(
        lootbox.address,
        ethers.utils.parseEther("10"),
        treasury.address,
        merkleRoot,
        merkleRoot
      );
    await lootboxSale.deployed();
  });

  it("List an Lootbox to sell", async function () {
    await lootbox.connect(admin).approve(lootboxSale.address, 0);
    await lootbox.connect(admin).approve(lootboxSale.address, 1);
    await lootbox.connect(admin).approve(lootboxSale.address, 2);

    await lootboxSale.connect(admin).addListing([0, 1]);
    expect(await lootboxSale.tokenListed(0)).to.eq(true);
    expect(await lootboxSale.tokenListed(1)).to.eq(true);

    await expect(
      lootboxSale.connect(admin).removeListing([2])
    ).to.be.revertedWith("NotActived()");
    await expect(lootboxSale.connect(admin).addListing([0])).to.be.revertedWith(
      "NotAbleToAdd()"
    );
  });

  it("Buy an NFT", async function () {
    // Get the total count of listings.
    const tokenId = 0;
    const price = await lootboxSale.price();

    const player3Address = await whitelisted[3].getAddress();
    const proof = tree.getHexProof(ethers.utils.keccak256(player3Address));

    // Approve BLT and Buy NFT from the marketplace.
    // await blt.connect(player3).approve(lootboxSale.address, listing.price);
    expect(
      await lootboxSale.connect(player3).buy(tokenId, proof, { value: price })
    )
      .to.emit(lootboxSale, "LootboxSold")
      .withArgs(tokenId, player3Address, price);

    // Check NFT was exchanged.
    expect(await lootbox.ownerOf(tokenId)).to.equal(player3Address);
    expect(await lootboxSale.tokenListed(tokenId)).to.eq(false);
  });

  it("Buy an NFT again with not whitelisted user", async () => {
    const tokenId = 1;

    const invalidAddress = await notWhitelisted[1].getAddress();
    const invalidMerkleProof = tree.getHexProof(
      ethers.utils.keccak256(invalidAddress)
    );

    await expect(
      lootboxSale.connect(notWhitelisted[1]).buy(tokenId, invalidMerkleProof)
    ).to.be.revertedWith("InvalidMerkleProof");
  });
});
