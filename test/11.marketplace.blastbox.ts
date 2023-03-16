import { expect } from 'chai'
import { ethers } from 'hardhat'

describe('Blast Royale Marketplace', function () {
  let blt: any
  let nft: any
  let market: any
  let admin: any
  let player1: any
  let player2: any
  let treasury1: any
  let treasury2: any
  let lootbox: any

  before('deploying', async () => {
    const signers = await ethers.getSigners()
    admin = signers[0]
    player1 = signers[1]
    player2 = signers[2]
    treasury1 = signers[3]
    treasury2 = signers[4]
  })

  it('Deploy Primary Token', async function () {
    const BlastToken = await ethers.getContractFactory('PrimaryToken')
    blt = await BlastToken.deploy(
      'Blast Royale',
      '$BLT',
      treasury2.address,
      treasury1.address,
      ethers.utils.parseEther('100000000')
    )
    await blt.deployed()
    await blt
      .connect(treasury1)
      .transfer(player2.address, ethers.utils.parseUnits('100'))
  })

  it('Deploy NFT', async function () {
    const BlastNFT = await ethers.getContractFactory('BlastEquipmentNFT')
    nft = await BlastNFT.connect(admin).deploy('Blast Royale', '$BLT', 'ipfs://111', 'ipfs://222')
    await nft.deployed()
    const mintTx = await nft
      .connect(admin)
      .safeMint(
        player1.address,
        [
          ethers.utils.keccak256('0x1000'),
          ethers.utils.keccak256('0x2000'),
          ethers.utils.keccak256('0x3000')
        ],
        ['ipfs://111_real', 'ipfs://222_real', 'ipfs://333_real'],
        [[1, 1, 1, 1, 1, 1], [1, 1, 1, 1, 1, 1], [1, 1, 1, 1, 1, 1]]
      )
    await mintTx.wait()
  })

  it('Deploy Lootbox', async () => {
    const BlastLootBox = await ethers.getContractFactory('BlastLootBox')
    lootbox = await BlastLootBox.connect(admin).deploy(
      'Lootbox',
      '$BLB',
      nft.address
    )
    await lootbox.deployed()

    // Equipment NFT mint to blast Lootbox contract
    await (
      await nft
        .connect(admin)
        .safeMint(
          lootbox.address,
          [
            ethers.utils.keccak256('0x1000'),
            ethers.utils.keccak256('0x2000'),
            ethers.utils.keccak256('0x3000'),
            ethers.utils.keccak256('0x1000'),
            ethers.utils.keccak256('0x2000'),
            ethers.utils.keccak256('0x3000'),
            ethers.utils.keccak256('0x1000'),
            ethers.utils.keccak256('0x2000'),
            ethers.utils.keccak256('0x3000')
          ],
          [
            'ipfs://111_real',
            'ipfs://222_real',
            'ipfs://333_real',
            'ipfs://111_real',
            'ipfs://222_real',
            'ipfs://333_real',
            'ipfs://111_real',
            'ipfs://222_real',
            'ipfs://333_real'
          ],
          [[1, 1, 1, 1, 1, 1], [1, 1, 1, 1, 1, 1], [1, 1, 1, 1, 1, 1], [1, 1, 1, 1, 1, 1], [1, 1, 1, 1, 1, 1], [1, 1, 1, 1, 1, 1], [1, 1, 1, 1, 1, 1], [1, 1, 1, 1, 1, 1], [1, 1, 1, 1, 1, 1]]
        )
    ).wait()

    // Lootbox SafeMint
    await (
      await lootbox.connect(admin).safeMint(
        [player1.address, player1.address],
        ['ipfs://lootbox_111', 'ipfs://lootbox_333'],
        [
          {
            token0: 0,
            token1: 1,
            token2: 2
          },
          {
            token0: 6,
            token1: 7,
            token2: 8
          }
        ],
        1
      )
    ).wait()

    await (
      await lootbox.connect(admin).safeMint(
        [admin.address],
        ['ipfs://lootbox_222'],
        [
          {
            token0: 3,
            token1: 4,
            token2: 5
          }
        ],
        2
      )
    ).wait()
  })

  it('Deploy Marketplace', async function () {
    const Lootbox = await ethers.getContractFactory('BlastBoxMarketplace')
    market = await Lootbox.connect(admin).deploy(lootbox.address)
    await market.deployed()
  })

  it('List a Box to sell', async function () {
    await lootbox.connect(player1).approve(market.address, 0)
    await market.connect(admin).setWhitelistTokens([blt.address])
    await expect(
      market
        .connect(player1)
        .addListing(0, ethers.utils.parseUnits('10'), blt.address)
    )
      .to.emit(market, 'ItemListed')
      .withArgs(
        0,
        0,
        player1.address,
        ethers.utils.parseUnits('10'),
        blt.address
      )

    const listingId = 0
    const totalListings = await market.activeListingCount()
    expect(totalListings.toNumber()).to.equal(1)

    // Get listing_id
    const listing = await market.listings(listingId)
    expect(listing.isActive).to.equal(true)
    expect(listing.price).to.equal(ethers.utils.parseUnits('10'))
    expect(listing.tokenId.toNumber()).to.equal(0)
  })

  it('Delist an NFT from the marketplace', async function () {
    await expect(market.connect(player1).removeListing(0))
      .to.emit(market, 'ItemDelisted')
      .withArgs(0, 0, player1.address)
  })

  it('Buy an lootbox', async function () {
    // Add a new isting
    await lootbox.connect(player1).approve(market.address, 0)
    await market.connect(admin).setWhitelistTokens([blt.address])
    await market
      .connect(player1)
      .addListing(0, ethers.utils.parseUnits('5'), blt.address)
    await lootbox.connect(player1).approve(market.address, 1)
    await market
      .connect(player1)
      .addListing(1, ethers.utils.parseUnits('10'), blt.address)

    // Get the total count of listings.
    let totalListings = await market.activeListingCount()
    expect(totalListings.toNumber()).to.equal(2)
    const listingId = 2
    const listing = await market.listings(listingId)

    // Approve BLT and Buy NFT from the marketplace.
    await blt.connect(player2).approve(market.address, listing.price)
    await expect(market.connect(player2).buy(listingId))
      .to.emit(market, 'ItemSold')
      .withArgs(2, 1, player1.address, player2.address, listing.price, 0, 0)
    totalListings = await market.activeListingCount()
    expect(totalListings.toNumber()).to.equal(1)

    // Check NFT was exchanged.
    expect(await lootbox.ownerOf(1)).to.equal(player2.address)

    // Check BLT was paid from player2 to player1
    expect(await blt.balanceOf(player1.address)).to.equal(
      ethers.utils.parseUnits('10')
    )
    expect(await blt.balanceOf(player2.address)).to.equal(
      ethers.utils.parseUnits('90')
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
    await blt.connect(player2).approve(market.address, listing.price)
    await expect(market.connect(player2).buy(listingId))
      .to.emit(market, 'ItemSold')
      .withArgs(
        1,
        0,
        player1.address,
        player2.address,
        listing.price,
        ethers.utils.parseUnits('0.1'),
        ethers.utils.parseUnits('0.025')
      )
    expect((await market.activeListingCount()).toNumber()).to.equal(0)

    // Check BLT was paid from player2 to player1 and Fees were applied
    expect(await blt.balanceOf(player1.address)).to.equal(
      ethers.utils.parseUnits('14.875')
    )
    expect(await blt.balanceOf(player2.address)).to.equal(
      ethers.utils.parseUnits('85')
    )
    expect(await blt.balanceOf(treasury1.address)).to.equal(
      ethers.utils.parseUnits('99999900.1')
    )
    expect(await blt.balanceOf(treasury2.address)).to.equal(
      ethers.utils.parseUnits('0.025')
    )
  })

  it('Pause contract', async () => {
    await market.connect(admin).pause(true)
    await expect(
      market
        .connect(player1)
        .addListing(0, ethers.utils.parseUnits('2'), blt.address)
    ).to.be.revertedWith('Pausable: paused')
    await expect(market.connect(player1).buy(0)).to.be.revertedWith(
      'Pausable: paused'
    )
    await market.connect(admin).pause(false)
    await lootbox.connect(admin).approve(market.address, 2)
    await market
      .connect(admin)
      .addListing(2, ethers.utils.parseUnits('10'), blt.address)
  })
})
