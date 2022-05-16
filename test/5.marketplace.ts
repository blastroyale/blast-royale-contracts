import { expect } from "chai";
import { ethers } from "hardhat";

// const uri = "https://blastroyale.com/nft/";

describe("Blast Royale Marketplace", function () {
  let blt: any;
  let nft: any;
  let market: any;
  let admin: any;
  let player1: any;
  let player2: any;
  let treasury1: any;
  let treasury2: any;

  before("deploying", async () => {
    const signers = await ethers.getSigners();
    admin = signers[0];
    player1 = signers[1];
    player2 = signers[2];
    treasury1 = signers[3];
    treasury2 = signers[4];
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
      .transfer(player2.address, ethers.utils.parseUnits("100"));
  });

  it("Deploy NFT", async function () {
    const BlastNFT = await ethers.getContractFactory("BlastEquipmentNFT");
    nft = await BlastNFT.connect(admin).deploy("Blast Royale", "$BLT");
    await nft.deployed();
    const mintTx = await nft
      .connect(admin)
      .safeMint(
        player1.address,
        ["ipfs://111", "ipfs://222", "ipfs://333"],
        [
          ethers.utils.keccak256("0x1000"),
          ethers.utils.keccak256("0x2000"),
          ethers.utils.keccak256("0x3000"),
        ],
        ["ipfs://111_real", "ipfs://222_real", "ipfs://333_real"]
      );
    await mintTx.wait();
  });

  it("Deploy Marketplace", async function () {
    const BlastNFT = await ethers.getContractFactory("Marketplace");
    market = await BlastNFT.connect(admin).deploy(nft.address);
    await market.deployed();
  });

  it("List an NFT to sell", async function () {
    await nft.connect(player1).approve(market.address, 0);
    await expect(
      market
        .connect(player1)
        .addListing(0, ethers.utils.parseUnits("10"), blt.address)
    )
      .to.emit(market, "ItemListed")
      .withArgs(
        0,
        0,
        player1.address,
        ethers.utils.parseUnits("10"),
        blt.address
      );

    const listingId = 0;
    const totalListings = await market.activeListingCount();
    expect(totalListings.toNumber()).to.equal(1);

    // Get listing_id
    const listing = await market.listings(listingId);
    expect(listing.isActive).to.equal(true);
    expect(listing.price).to.equal(ethers.utils.parseUnits("10"));
    expect(listing.tokenId.toNumber()).to.equal(0);
  });

  it("Delist an NFT from the marketplace", async function () {
    await expect(market.connect(player1).removeListing(0))
      .to.emit(market, "ItemDelisted")
      .withArgs(0, 0, player1.address);
  });

  it("Buy an NFT", async function () {
    // Add a new isting
    await nft.connect(player1).approve(market.address, 0);
    await market
      .connect(player1)
      .addListing(0, ethers.utils.parseUnits("5"), blt.address);
    await nft.connect(player1).approve(market.address, 1);
    await market
      .connect(player1)
      .addListing(1, ethers.utils.parseUnits("10"), blt.address);

    // Get the total count of listings.
    let totalListings = await market.activeListingCount();
    expect(totalListings.toNumber()).to.equal(2);
    const listingId = 2;
    const listing = await market.listings(listingId);

    // Approve BLT and But NFT from the marketplace.
    await blt.connect(player2).approve(market.address, listing.price);
    await expect(market.connect(player2).buy(listingId))
      .to.emit(market, "ItemSold")
      .withArgs(2, 1, player1.address, player2.address, listing.price, 0, 0);
    totalListings = await market.activeListingCount();
    expect(totalListings.toNumber()).to.equal(1);

    // Check NFT was exchanged.
    expect(await nft.ownerOf(1)).to.equal(player2.address);

    // Check BLT was paid from player2 to player1
    expect(await blt.balanceOf(player1.address)).to.equal(
      ethers.utils.parseUnits("10")
    );
    expect(await blt.balanceOf(player2.address)).to.equal(
      ethers.utils.parseUnits("90")
    );
  });

  it("Add Fees", async function () {
    await expect(
      market
        .connect(admin)
        .setFee(200, treasury1.address, 50, treasury2.address)
    )
      .to.emit(market, "FeesChanged")
      .withArgs(200, treasury1.address, 50, treasury2.address, admin.address);
    const listingId = 1;
    const listing = await market.listings(listingId);
    await blt.connect(player2).approve(market.address, listing.price);
    await expect(market.connect(player2).buy(listingId))
      .to.emit(market, "ItemSold")
      .withArgs(
        1,
        0,
        player1.address,
        player2.address,
        listing.price,
        ethers.utils.parseUnits("0.1"),
        ethers.utils.parseUnits("0.025")
      );
    expect((await market.activeListingCount()).toNumber()).to.equal(0);

    // Check BLT was paid from player2 to player1 and Fees were applied
    expect(await blt.balanceOf(player1.address)).to.equal(
      ethers.utils.parseUnits("14.875")
    );
    expect(await blt.balanceOf(player2.address)).to.equal(
      ethers.utils.parseUnits("85")
    );
    expect(await blt.balanceOf(treasury1.address)).to.equal(
      ethers.utils.parseUnits("0.1")
    );
    expect(await blt.balanceOf(treasury2.address)).to.equal(
      ethers.utils.parseUnits("0.025")
    );
  });

  it("Pause contract", async () => {
    await market.connect(admin).pause(true);
    await expect(
      market
        .connect(player1)
        .addListing(0, ethers.utils.parseUnits("2"), blt.address)
    ).to.be.revertedWith("Pausable: paused");
    await expect(market.connect(player1).buy(0)).to.be.revertedWith(
      "Pausable: paused"
    );
    await market.connect(admin).pause(false);
    await nft.connect(player1).approve(market.address, 2);
    await market
      .connect(player1)
      .addListing(2, ethers.utils.parseUnits("10"), blt.address);
  });
});
