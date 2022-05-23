import { expect } from "chai";
import { ethers } from "hardhat";

describe("Blast Royale Marketplace Lootbox", function () {
  let blt: any;
  let nft: any;
  let lootbox: any;
  let market: any;
  let admin: any;
  let player1: any;
  let player2: any;

  before("deploying", async () => {
    const signers = await ethers.getSigners();
    admin = signers[0];
    player1 = signers[1];
    player2 = signers[2];
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
    const mintTx = await nft
      .connect(admin)
      .safeMint(
        player1.address,
        [
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
        ],
        [
          "ipfs://111_real",
          "ipfs://222_real",
          "ipfs://333_real",
          "ipfs://111_real",
          "ipfs://222_real",
          "ipfs://333_real",
        ]
      );
    await mintTx.wait();
  });

  it("Deploy Lootbox", async () => {
    const BlastLootBox = await ethers.getContractFactory("BlastLootBox");
    lootbox = await BlastLootBox.connect(admin).deploy(
      "Lootbox",
      "$BLB",
      nft.address
    );
    await lootbox.deployed();
    await (
      await lootbox.connect(admin).safeMint(
        [admin.address],
        ["ipfs://lootbox_111"],
        [
          {
            token0: 0,
            token1: 1,
            token2: 2,
          },
        ],
        1
      )
    ).wait();

    await (
      await lootbox.connect(admin).safeMint(
        [admin.address],
        ["ipfs://lootbox_2"],
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
    const BlastNFT = await ethers.getContractFactory("MarketplaceLootbox");
    market = await BlastNFT.connect(admin).deploy(lootbox.address);
    await market.deployed();
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

  // it("Delist an NFT from the marketplace", async function () {
  //   await expect(market.connect(admin).removeListing(0))
  //     .to.emit(market, "LootboxDelisted")
  //     .withArgs(0, player1.address);
  // });

  it("Buy an NFT", async function () {
    // Get the total count of listings.
    const tokenId = 0;
    const listing = await market.listings(tokenId);

    // Approve BLT and But NFT from the marketplace.
    await blt.connect(player1).approve(market.address, listing.price);
    await expect(market.connect(player1).buy(tokenId))
      .to.emit(market, "LootboxSold")
      .withArgs(0, admin.address, player1.address, listing.price);

    // Check NFT was exchanged.
    expect(await lootbox.ownerOf(0)).to.equal(player1.address);

    // Check BLT was paid from player2 to player1
    expect(await blt.balanceOf(player1.address)).to.equal(
      ethers.utils.parseUnits("90")
    );
  });

  it("Buy an NFT again", async () => {
    const tokenId = 1;
    const listing = await market.listings(tokenId);

    // Approve BLT and But NFT from the marketplace.
    await blt.connect(player1).approve(market.address, listing.price);

    await expect(market.connect(player1).buy(tokenId))
      .to.emit(market, "LootboxSold")
      .withArgs(1, admin.address, player1.address, listing.price);

    expect(await market.getOwnedCount(player1.address, 1)).to.eq(1);
    expect(await market.getOwnedCount(player1.address, 2)).to.eq(1);
  });
});
