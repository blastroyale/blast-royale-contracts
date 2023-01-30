import { expect } from 'chai'
import { ethers } from 'hardhat'

describe('Blast Royale Marketplace', function () {
  let cs: any
  let market: any
  let admin: any
  let player1: any
  let player2: any
  let treasury1: any
  let treasury2: any

  before('deploying', async () => {
    const signers = await ethers.getSigners()
    admin = signers[0]
    player1 = signers[1]
    player2 = signers[2]
    treasury1 = signers[3]
    treasury2 = signers[4]
  })

  it('Deploy Secondary Token', async function () {
    const CSToken = await ethers.getContractFactory('SecondaryToken')
    cs = await CSToken.deploy(
      'Craft Spice',
      '$CS',
      ethers.utils.parseEther('100000000'),
      admin.address
    )
    await cs.deployed()
    await cs
      .connect(admin)
      .transfer(player1.address, ethers.utils.parseUnits('100'))
  })

  it('Deploy Marketplace', async function () {
    const CSmarketplace = await ethers.getContractFactory('CSMarketplace')
    market = await CSmarketplace.connect(admin).deploy(cs.address)
    await market.deployed()
    await market.connect(admin).flipIsUsingMatic()
  })

  it('List CS to sell', async function () {
    await cs.connect(player1).approve(market.address, ethers.utils.parseUnits('2'))
    await expect(
      market
        .connect(player1)
        .addListing(ethers.utils.parseUnits('2'), ethers.utils.parseUnits('10'), ethers.constants.AddressZero)
    )
      .to.emit(market, 'ItemListed')
      .withArgs(
        0,
        ethers.utils.parseUnits('2'),
        player1.address,
        ethers.utils.parseUnits('10'),
        ethers.constants.AddressZero
      )

    const listingId = 0
    const totalListings = await market.activeListingCount()
    expect(totalListings.toNumber()).to.equal(1)

    // Get listing_id
    const listing = await market.listings(listingId)
    expect(listing.isActive).to.equal(true)
    expect(listing.price).to.equal(ethers.utils.parseUnits('10'))
    expect(listing.amount).to.equal(ethers.utils.parseUnits('2'))
  })

  it('Delist a CS listing from the marketplace', async function () {
    await expect(market.connect(player1).removeListing(0))
      .to.emit(market, 'ItemDelisted')
      .withArgs(0, ethers.utils.parseUnits('2'), player1.address)
  })

  it('Buy CS', async function () {
    // Add a new isting
    await cs.connect(player1).approve(market.address, ethers.utils.parseUnits('4'))
    await market
      .connect(player1)
      .addListing(ethers.utils.parseUnits('2'), ethers.utils.parseUnits('10'), ethers.constants.AddressZero)

    await market
      .connect(player1)
      .addListing(ethers.utils.parseUnits('2'), ethers.utils.parseUnits('10'), ethers.constants.AddressZero)

    // Get the total count of listings.
    let totalListings = await market.activeListingCount()
    expect(totalListings.toNumber()).to.equal(2)
    const listingId = 2
    const listing = await market.listings(listingId)

    const player1Balance = await player1.getBalance()

    // Buy CS from the marketplace.
    await expect(await market.connect(player2).buy(listingId, { value: ethers.utils.parseUnits('10') }))
      .to.emit(market, 'ItemSold')
      .withArgs(2, ethers.utils.parseUnits('2'), player1.address, player2.address, listing.price, 0, 0)
    totalListings = await market.activeListingCount()
    expect(totalListings.toNumber()).to.equal(1)

    // Check NFT was exchanged.
    expect(await cs.balanceOf(player2.address)).to.equal(ethers.utils.parseUnits('2'))

    // Check Eth was paid from player2 to player1
    const player1NewBalance = await player1.getBalance()
    expect(player1NewBalance.toString()).to.equal(
      ethers.utils.parseUnits('10').add(player1Balance).toString()
    )
  })

  it('Add Fees', async function () {
    await expect(
      market
        .connect(admin)
        .setFee(200, treasury1.address, 50, treasury2.address)
    )
      .to.emit(market, 'FeesChanged')
      .withArgs(200, treasury1.address, 50, treasury2.address, admin.address)
    const listingId = 1
    const listing = await market.listings(listingId)
    await expect(market.connect(player2).buy(listingId, { value: ethers.utils.parseUnits('10') }))
      .to.emit(market, 'ItemSold')
      .withArgs(
        1, ethers.utils.parseUnits('2'), player1.address, player2.address, listing.price,
        ethers.utils.parseUnits('0.2'),
        ethers.utils.parseUnits('0.05')
      )
    expect((await market.activeListingCount()).toNumber()).to.equal(0)

    // Check if eth was paid to treasuries with the transactions
    expect(await treasury1.getBalance()).to.equal(
      ethers.utils.parseUnits('10000.2')
    )
    expect(await treasury2.getBalance()).to.equal(
      ethers.utils.parseUnits('10000.05')
    )
  })

  it('Pause contract', async () => {
    await cs.connect(player1).approve(market.address, ethers.utils.parseUnits('2'))
    await market.connect(admin).pause(true)
    await expect(
      market
        .connect(player1)
        .addListing(ethers.utils.parseUnits('2'), ethers.utils.parseUnits('10'), ethers.constants.AddressZero)
    ).to.be.revertedWith('Pausable: paused')
    await expect(market.connect(player1).buy(0)).to.be.revertedWith(
      'Pausable: paused'
    )
    await market.connect(admin).pause(false)
    await cs.connect(player1).approve(market.address, ethers.utils.parseUnits('2'))
    await market
      .connect(player1)
      .addListing(ethers.utils.parseUnits('2'), ethers.utils.parseUnits('10'), ethers.constants.AddressZero)
  })
})
