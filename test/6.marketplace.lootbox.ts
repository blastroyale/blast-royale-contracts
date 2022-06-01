import { expect } from "chai";
import { Signer } from "ethers";
import { ethers } from "hardhat";
import { MerkleTree } from "merkletreejs";

describe("Blast Royale Marketplace Lootbox", function () {
  let blt: any;
  let nft: any;
  let lootbox: any;
  let market: any;
  let admin: any;
  let player1: any;
  let player2: any;
  let whitelisted: Signer[];
  let notWhitelisted: Signer[];
  let tree: any;

  before("deploying", async () => {
    const signers = await ethers.getSigners();
    admin = signers[0];
    player1 = signers[1];
    player2 = signers[2];

    whitelisted = signers.slice(0, 5);
    notWhitelisted = signers.slice(5, 10);
  });

  it("Deploy Primary Token", async function () {
    const BlastToken = await ethers.getContractFactory("PrimaryToken");
    blt = await BlastToken.deploy(
      "Blast Royale",
      "$BLT",
      ethers.utils.parseEther("100000000")
    );
    await blt.deployed();
    await blt
      .connect(admin)
      .transfer(player1.address, ethers.utils.parseUnits("100"));
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
        [player1.address, player1.address],
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
        [player2.address],
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
    const merkleRoot = tree.getHexRoot();

    const LootboxMarketplce = await ethers.getContractFactory(
      "MarketplaceLootbox"
    );
    market = await LootboxMarketplce.connect(admin).deploy(
      lootbox.address,
      merkleRoot
    );
    await market.deployed();

    await (
      await market.connect(admin).setWhitelistTokens([blt.address])
    ).wait();
  });

  it("List an Lootbox to sell", async function () {
    await lootbox.connect(admin).approve(market.address, 0);
    await expect(
      market
        .connect(admin)
        .addListing(0, ethers.utils.parseUnits("10"), blt.address)
    )
      .to.emit(market, "LootboxListed")
      .withArgs(0, admin.address, ethers.utils.parseUnits("10"), blt.address);

    await lootbox.connect(admin).approve(market.address, 1);
    await expect(
      market
        .connect(admin)
        .addListing(1, ethers.utils.parseUnits("20"), blt.address)
    )
      .to.emit(market, "LootboxListed")
      .withArgs(1, admin.address, ethers.utils.parseUnits("20"), blt.address);

    const tokenId = 0;
    const totalListings = await market.activeListingCount();
    expect(totalListings.toNumber()).to.equal(2);

    // Get listing_id
    const listing = await market.listings(tokenId);
    expect(listing.isActive).to.equal(true);
    expect(listing.price).to.equal(ethers.utils.parseUnits("10"));
    expect(listing.tokenId.toNumber()).to.equal(0);
  });

  it("Delist an NFT from the marketplace", async function () {
    await expect(market.connect(admin).removeListing(0))
      .to.emit(market, "LootboxDelisted")
      .withArgs(0, admin.address);
  });

  it("Buy an NFT", async function () {
    // Get the total count of listings.
    const tokenId = 0;
    const listing = await market.listings(tokenId);

    const adminAddress = await whitelisted[1].getAddress();
    const merkleProof = tree.getHexProof(ethers.utils.keccak256(adminAddress));

    // Approve BLT and But NFT from the marketplace.
    await blt.connect(player1).approve(market.address, listing.price);
    await expect(market.connect(player1).buy(tokenId, merkleProof))
      .to.emit(market, "LootboxSold")
      .withArgs(0, admin.address, player1.address, listing.price);

    // Check NFT was exchanged.
    expect(await lootbox.ownerOf(0)).to.equal(player1.address);

    // Check BLT was paid from player2 to player1
    expect(await blt.balanceOf(player1.address)).to.equal(
      ethers.utils.parseUnits("90")
    );
  });

  it("Buy an NFT again with not whitelisted user", async () => {
    const tokenId = 1;
    const listing = await market.listings(tokenId);

    const invalidAddress = await notWhitelisted[1].getAddress();
    const invalidMerkleProof = tree.getHexProof(
      ethers.utils.keccak256(invalidAddress)
    );
    // Approve BLT and But NFT from the marketplace.
    await blt.connect(notWhitelisted[1]).approve(market.address, listing.price);

    await expect(
      market.connect(notWhitelisted[1]).buy(tokenId, invalidMerkleProof)
    ).to.be.revertedWith("InvalidMerkleProof");
  });
});
