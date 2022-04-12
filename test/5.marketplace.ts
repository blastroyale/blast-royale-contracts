import { expect } from "chai";
import { ethers } from "hardhat";
import { setup, IBlast } from "./utils/setup";

describe("5 - Blast Royale Marketplace", function () {
  let blast: IBlast;

  before("deploying", async () => {
    blast = await setup();
  });

  it("Deploy Marketplace", async function () {
    const BlastNFT = await ethers.getContractFactory("Marketplace");
    blast.market = await BlastNFT.connect(blast.owner).deploy(
      blast.equipment.address,
      blast.blt.address
    );
    await blast.market.deployed();
  });

  it("List an NFT to sell", async function () {
    await blast.equipment
      .connect(blast.player1)
      .approve(blast.market.address, 0);
    await expect(
      blast.market
        .connect(blast.player1)
        .addListing(0, ethers.utils.parseUnits("10"))
    )
      .to.emit(blast.market, "ItemListed")
      .withArgs(0, 0, blast.player1.address, ethers.utils.parseUnits("10"));

    const listingId = 0;
    const totalListings = await blast.market.activeListingCount();
    expect(totalListings.toNumber()).to.equal(1);

    // Get listing_id
    const listing = await blast.market.listings(listingId);
    expect(listing.isActive).to.equal(true);
    expect(listing.price).to.equal(ethers.utils.parseUnits("10"));
    expect(listing.tokenId.toNumber()).to.equal(0);
  });

  it("Delist an NFT from the blast.marketplace", async function () {
    await expect(blast.market.connect(blast.player1).removeListing(0))
      .to.emit(blast.market, "ItemDelisted")
      .withArgs(0, 0, blast.player1.address);
  });

  it("Buy an NFT", async function () {
    // Add a new Listing
    await blast.equipment
      .connect(blast.player1)
      .approve(blast.market.address, 0);
    await blast.market
      .connect(blast.player1)
      .addListing(0, ethers.utils.parseUnits("5"));
    await blast.equipment
      .connect(blast.player1)
      .approve(blast.market.address, 1);
    await blast.market
      .connect(blast.player1)
      .addListing(1, ethers.utils.parseUnits("10"));

    // Get the total count of listings.
    let totalListings = await blast.market.activeListingCount();
    expect(totalListings.toNumber()).to.equal(2);
    const listingId = 2;
    const listing = await blast.market.listings(listingId);

    // Approve BLT and But NFT from the blast.marketplace.
    await blast.blt
      .connect(blast.player2)
      .approve(blast.market.address, listing.price);
    await expect(blast.market.connect(blast.player2).buy(listingId))
      .to.emit(blast.market, "ItemSold")
      .withArgs(
        2,
        1,
        blast.player1.address,
        blast.player2.address,
        listing.price,
        0,
        0
      );
    totalListings = await blast.market.activeListingCount();
    expect(totalListings.toNumber()).to.equal(1);

    // Check NFT was exchanged.
    expect(await blast.equipment.ownerOf(1)).to.equal(blast.player2.address);

    // Check BLT was paid from blast.player2 to blast.player1
    expect(await blast.blt.balanceOf(blast.player1.address)).to.equal(
      ethers.utils.parseUnits("1010")
    );
    expect(await blast.blt.balanceOf(blast.player2.address)).to.equal(
      ethers.utils.parseUnits("1990")
    );
  });

  it("Add Fees", async function () {
    await expect(
      blast.market
        .connect(blast.owner)
        .setFee(200, blast.treasury.address, 50, blast.treasury2.address)
    )
      .to.emit(blast.market, "FeesChanged")
      .withArgs(
        200,
        blast.treasury.address,
        50,
        blast.treasury2.address,
        blast.owner.address
      );
    const listingId = 1;
    const listing = await blast.market.listings(listingId);
    await blast.blt
      .connect(blast.player2)
      .approve(blast.market.address, listing.price);
    await expect(blast.market.connect(blast.player2).buy(listingId))
      .to.emit(blast.market, "ItemSold")
      .withArgs(
        1,
        0,
        blast.player1.address,
        blast.player2.address,
        listing.price,
        ethers.utils.parseUnits("0.1"),
        ethers.utils.parseUnits("0.025")
      );
    expect((await blast.market.activeListingCount()).toNumber()).to.equal(0);

    // Check BLT was paid from blast.player2 to blast.player1 and Fees were applied
    expect(await blast.blt.balanceOf(blast.player1.address)).to.equal(
      ethers.utils.parseUnits("1014.875")
    );
    expect(await blast.blt.balanceOf(blast.player2.address)).to.equal(
      ethers.utils.parseUnits("1985")
    );
    expect(await blast.blt.balanceOf(blast.treasury.address)).to.equal(
      ethers.utils.parseUnits("0.1")
    );
    expect(await blast.blt.balanceOf(blast.treasury2.address)).to.equal(
      ethers.utils.parseUnits("0.025")
    );
  });

  it("Pause contract", async () => {
    await blast.market.connect(blast.owner).pause(true);
    await expect(
      blast.market
        .connect(blast.player1)
        .addListing(2, ethers.utils.parseUnits("2"))
    ).to.be.revertedWith("Pausable: paused");
    await expect(blast.market.connect(blast.player1).buy(2)).to.be.revertedWith(
      "Pausable: paused"
    );
    await blast.market.connect(blast.owner).pause(false);
    await blast.equipment
      .connect(blast.player1)
      .approve(blast.market.address, 2);
    await blast.market
      .connect(blast.player1)
      .addListing(2, ethers.utils.parseUnits("10"));
  });
});
