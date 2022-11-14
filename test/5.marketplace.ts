import { expect } from 'chai'
import { ethers } from 'hardhat'
import { deployBLST, deployMarketplace, deployPrimary, deploySecondary, mintBLST } from './helper'

// const uri = "https://blastroyale.com/nft/";

describe('Blast Royale Marketplace', function () {
  let owner: any
  let treasury: any
  let treasury1: any
  let treasury2: any
  let addr1: any
  let addr2: any
  let blst: any
  let primary: any
  let secondary: any
  let marketplace: any

  before('deploying', async () => {
    [owner, treasury, addr1, addr2, treasury1, treasury2] = await ethers.getSigners()
    primary = await deployPrimary(owner, owner, treasury)
    secondary = await deploySecondary(owner)
    blst = await deployBLST(owner)
    marketplace = await deployMarketplace(owner, blst.address)
    await secondary
      .connect(owner)
      .claim(addr1.address, ethers.utils.parseEther('10000'))

    await primary
      .connect(treasury)
      .transfer(addr1.address, ethers.utils.parseEther('10000000'))

    await mintBLST(owner, blst, addr1.address, 3)
  })

  it('List an NFT to sell', async function () {
    await blst.connect(addr1).approve(marketplace.address, 0)
    await marketplace.connect(owner).setWhitelistTokens([primary.address])
    await expect(
      marketplace
        .connect(addr1)
        .addListing(0, ethers.utils.parseUnits('10'), primary.address)
    )
      .to.emit(marketplace, 'ItemListed')
      .withArgs(
        0,
        0,
        addr1.address,
        ethers.utils.parseUnits('10'),
        primary.address
      )

    const listingId = 0
    const totalListings = await marketplace.activeListingCount()
    expect(totalListings.toNumber()).to.equal(1)

    // Get listing_id
    const listing = await marketplace.listings(listingId)
    expect(listing.isActive).to.equal(true)
    expect(listing.price).to.equal(ethers.utils.parseUnits('10'))
    expect(listing.tokenId.toNumber()).to.equal(0)
  })

  it('Delist an NFT from the marketplace', async function () {
    await expect(marketplace.connect(addr1).removeListing(0))
      .to.emit(marketplace, 'ItemDelisted')
      .withArgs(0, 0, addr1.address)
  })

  it('Buy an NFT', async function () {
    // Add a new isting
    await blst.connect(addr1).approve(marketplace.address, 0)
    await marketplace.connect(owner).setWhitelistTokens([primary.address])
    await marketplace
      .connect(addr1)
      .addListing(0, ethers.utils.parseUnits('5'), primary.address)
    await blst.connect(addr1).approve(marketplace.address, 1)
    await marketplace
      .connect(addr1)
      .addListing(1, ethers.utils.parseUnits('10'), primary.address)

    // Get the total count of listings.
    let totalListings = await marketplace.activeListingCount()
    expect(totalListings.toNumber()).to.equal(2)
    const listingId = 2
    const listing = await marketplace.listings(listingId)

    // Approve primary and But NFT from the marketplace.
    await primary.connect(addr2).approve(marketplace.address, ethers.constants.MaxUint256)
    await expect(marketplace.connect(addr2).buy(listingId))
      .to.emit(marketplace, 'ItemSold')
      .withArgs(2, 1, addr1.address, addr2.address, listing.price, 0, 0)
    totalListings = await marketplace.activeListingCount()
    expect(totalListings.toNumber()).to.equal(1)

    // Check NFT was exchanged.
    expect(await blst.ownerOf(1)).to.equal(addr2.address)

    // Check primary was paid from addr2 to addr1
    expect(await primary.balanceOf(addr1.address)).to.equal(
      ethers.utils.parseUnits('10')
    )
    expect(await primary.balanceOf(addr2.address)).to.equal(
      ethers.utils.parseUnits('90')
    )
  })

  it('Add Fees', async function () {
    await expect(
      marketplace
        .connect(owner)
        .setFee(200, treasury1.address, 50, treasury2.address)
    )
      .to.emit(marketplace, 'FeesChanged')
      .withArgs(200, treasury1.address, 50, treasury2.address, owner.address)
    const listingId = 1
    const listing = await marketplace.listings(listingId)
    await primary.connect(addr2).approve(marketplace.address, listing.price)
    await expect(marketplace.connect(addr2).buy(listingId))
      .to.emit(marketplace, 'ItemSold')
      .withArgs(
        1,
        0,
        addr1.address,
        addr2.address,
        listing.price,
        ethers.utils.parseUnits('0.1'),
        ethers.utils.parseUnits('0.025')
      )
    expect((await marketplace.activeListingCount()).toNumber()).to.equal(0)

    // Check primary was paid from addr2 to addr1 and Fees were applied
    expect(await primary.balanceOf(addr1.address)).to.equal(
      ethers.utils.parseUnits('14.875')
    )
    expect(await primary.balanceOf(addr2.address)).to.equal(
      ethers.utils.parseUnits('85')
    )
    expect(await primary.balanceOf(treasury1.address)).to.equal(
      ethers.utils.parseUnits('99999900.1')
    )
    expect(await primary.balanceOf(treasury2.address)).to.equal(
      ethers.utils.parseUnits('0.025')
    )
  })

  it('Pause contract', async () => {
    await marketplace.connect(owner).pause(true)
    await expect(
      marketplace
        .connect(addr1)
        .addListing(0, ethers.utils.parseUnits('2'), primary.address)
    ).to.be.revertedWith('Pausable: paused')
    await expect(marketplace.connect(addr1).buy(0)).to.be.revertedWith(
      'Pausable: paused'
    )
    await marketplace.connect(owner).pause(false)
    await blst.connect(addr1).approve(marketplace.address, 2)
    await marketplace
      .connect(addr1)
      .addListing(2, ethers.utils.parseUnits('10'), primary.address)
  })
})
