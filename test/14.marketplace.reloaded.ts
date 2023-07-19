import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers'
import { expect } from 'chai'
import { Contract } from 'ethers'
import { ethers } from 'hardhat'

describe('Marlketplace contract', function () {
  let nft: Contract
  let marketplace: Contract
  let erc1155: Contract
  let primaryToken: Contract
  let admin: any
  let player1: SignerWithAddress

  before('deploying', async () => {
    const signers = await ethers.getSigners()
    admin = signers[0]
    player1 = signers[1]
  })

  it('Deploys ERC721 contract', async function () {
    const NFT = await ethers.getContractFactory('BlastEquipmentNFT')
    nft = await NFT.deploy(
      'Blast Equipment', '$BLST',
      'https://static.blastroyale.com/previewMetadata.json',
      'https://static.blastroyale.com/'
    )
    await nft.deployed()
  })

  it('Deploys ERC1155 contract', async function () {
    const ERC1155 = await ethers.getContractFactory('ReloadedNFT')
    erc1155 = await ERC1155.deploy()
    await erc1155.deployed()
  })

  it('Deploys Primary token contract', async function () {
    const PrimaryToken = await ethers.getContractFactory('PrimaryToken')
    primaryToken = await PrimaryToken.deploy('Test Token', 'TK', admin.address, player1.address, '512000000000000000000000000')
    await primaryToken.deployed()
  })

  it('Deploys marketplace contract', async function () {
    const Marketplace = await ethers.getContractFactory('MarketplaceReloaded')
    marketplace = await Marketplace.connect(admin).deploy()
    await marketplace.deployed()
  })

  it('can add listing for ERC721', async function () {
    // mint 2 nfts
    await nft.connect(admin).safeMint(admin.address, [ethers.utils.formatBytes32String('0x999'), ethers.utils.formatBytes32String('0x999')], ['ipfs://real_', 'ipfs://real_'], [{ maxLevel: 5, maxDurability: 1, maxReplication: 2, adjective: 3, rarity: 4, grade: 6 }, { maxLevel: 5, maxDurability: 1, maxReplication: 2, adjective: 3, rarity: 4, grade: 6 }])

    const amount = await nft.balanceOf(admin.address)

    expect(
      amount.toString()
    ).to.equal('2')

    expect(
      await nft.ownerOf(0)
    ).to.equal(admin.address)

    expect(
      await nft.ownerOf(1)
    ).to.equal(admin.address)
    // whitelist nft contract
    await marketplace.connect(admin).setWhitelistNFTContracts([nft.address])

    await nft.connect(admin).setApprovalForAll(marketplace.address, true)
    // add listing
    await expect(
      marketplace
        .connect(admin)
        .addListing([0, 1], 100, ethers.constants.AddressZero, nft.address, [1, 1])
    )
      .to.emit(marketplace, 'ItemListed')
      .withArgs(0, [0, 1], admin.address, 100, ethers.constants.AddressZero, nft.address)

    // nfts ownership is now the marketplace
    expect(
      await nft.ownerOf(0)
    ).to.equal(marketplace.address)

    expect(
      await nft.ownerOf(1)
    ).to.equal(marketplace.address)
  })

  it('can add listing for erc1155', async function () {
    // mint erc1155 id0 = 1, id1 = 2
    await erc1155.connect(admin).mintBatch(admin.address, [0, 1], [1, 2], '0x00')
    let amount = await erc1155.balanceOfBatch([admin.address, admin.address], [0, 1])

    expect(
      amount[0].toString()
    ).to.equal('1')

    expect(
      amount[1].toString()
    ).to.equal('2')

    // whitelist nft contract
    await marketplace.connect(admin).setWhitelistNFTContracts([erc1155.address])

    await erc1155.connect(admin).setApprovalForAll(marketplace.address, true)

    // add listing
    await expect(
      marketplace
        .connect(admin)
        .addListing([0, 1], 200, ethers.constants.AddressZero, erc1155.address, [1, 2])
    )
      .to.emit(marketplace, 'ItemListed')
      .withArgs(1, [0, 1], admin.address, 200, ethers.constants.AddressZero, erc1155.address)

    // check balance of marketplace
    amount = await erc1155.balanceOfBatch([marketplace.address, marketplace.address], [0, 1])

    expect(
      amount[0].toString()
    ).to.equal('1')

    expect(
      amount[1].toString()
    ).to.equal('2')
  })

  it('can add batch listing for ERC721', async function () {
    // mint 2 nfts
    await nft.connect(admin).safeMint(admin.address, [ethers.utils.formatBytes32String('0x999'), ethers.utils.formatBytes32String('0x999')], ['ipfs://real_', 'ipfs://real_'], [{ maxLevel: 5, maxDurability: 1, maxReplication: 2, adjective: 3, rarity: 4, grade: 6 }, { maxLevel: 5, maxDurability: 1, maxReplication: 2, adjective: 3, rarity: 4, grade: 6 }])

    const amount = await nft.balanceOf(admin.address)

    expect(
      amount.toString()
    ).to.equal('2')

    expect(
      await nft.ownerOf(2)
    ).to.equal(admin.address)

    expect(
      await nft.ownerOf(3)
    ).to.equal(admin.address)

    // add listing
    await expect(
      marketplace
        .connect(admin)
        .addBatchListing([2, 3], [100, 200], ethers.constants.AddressZero, nft.address, [1, 1])
    )
      .to.emit(marketplace, 'ItemListed')
      .withArgs(2, [2], admin.address, 100, ethers.constants.AddressZero, nft.address)
      .to.emit(marketplace, 'ItemListed')
      .withArgs(3, [3], admin.address, 200, ethers.constants.AddressZero, nft.address)

    // nfts ownership is now the marketplace
    expect(
      await nft.ownerOf(2)
    ).to.equal(marketplace.address)

    expect(
      await nft.ownerOf(3)
    ).to.equal(marketplace.address)
  })

  it('can add batch listing for ERC1155', async function () {
    // mint erc1155 id2 = 1, id3 = 2
    await erc1155.connect(admin).mintBatch(admin.address, [2, 3], [1, 2], '0x00')
    let amount = await erc1155.balanceOfBatch([admin.address, admin.address], [2, 3])

    expect(
      amount[0].toString()
    ).to.equal('1')

    expect(
      amount[1].toString()
    ).to.equal('2')

    // add listing
    await expect(
      marketplace
        .connect(admin)
        .addBatchListing([2, 3], [200, 100], ethers.constants.AddressZero, erc1155.address, [1, 2])
    )
      .to.emit(marketplace, 'ItemListed')
      .withArgs(4, [2], admin.address, 200, ethers.constants.AddressZero, erc1155.address)
      .to.emit(marketplace, 'ItemListed')
      .withArgs(5, [3], admin.address, 100, ethers.constants.AddressZero, erc1155.address)

    // check balance of marketplace
    amount = await erc1155.balanceOfBatch([marketplace.address, marketplace.address], [2, 3])

    expect(
      amount[0].toString()
    ).to.equal('1')

    expect(
      amount[1].toString()
    ).to.equal('2')
  })

  it('can buy', async function () {
    // listing id0 = token id 0,1 ERC71 $100
    // listing id1 = token id 0 x 1,1 x 2 ERC1155 $200
    // listing id 2,3 = token id 2,3 ERC721 $100 $200
    // listing id 4,5 = token id 2 x 1,3 x 2 ERC1155 $200 $100
    let amount = await erc1155.balanceOfBatch([admin.address], [2])

    // flip using matic
    await marketplace.connect(admin).flipIsUsingMatic()

    expect(
      amount[0].toString()
    ).to.equal('0')

    // player 1 buys listing id 4
    await expect(
      marketplace
        .connect(player1)
        .buy(4, { value: 200 })
    )
      .to.emit(marketplace, 'ItemSold')
      .withArgs(4, [2], admin.address, player1.address, 200, 0, 0, erc1155.address)

    // check balance of player1
    amount = await erc1155.balanceOfBatch([player1.address], [2])

    expect(
      amount[0].toString()
    ).to.equal('1')

    // player 1 buys listing id 0 and 1
    await expect(
      marketplace
        .connect(player1)
        .buy(0, { value: 100 })
    )
      .to.emit(marketplace, 'ItemSold')
      .withArgs(0, [0, 1], admin.address, player1.address, 100, 0, 0, nft.address)

    await expect(
      marketplace
        .connect(player1)
        .buy(1, { value: 200 })
    )
      .to.emit(marketplace, 'ItemSold')
      .withArgs(1, [0, 1], admin.address, player1.address, 200, 0, 0, erc1155.address)

    // check balance of player1
    const ERC721owner1 = await nft.ownerOf(0)
    const ERC721owner2 = await nft.ownerOf(1)
    const ERC1155Amount = await erc1155.balanceOfBatch([player1.address, player1.address], [0, 1])

    expect(
      ERC1155Amount[0].toString()
    ).to.equal('1')

    expect(
      ERC1155Amount[1].toString()
    ).to.equal('2')

    expect(
      ERC721owner1
    ).to.equal(player1.address)

    expect(
      ERC721owner2
    ).to.equal(player1.address)
  })

  it('can set price and buy with ERC20 token', async function () {
    // cannot buy when the required token is different
    // flip using matic
    await marketplace.connect(admin).flipIsUsingMatic()

    await expect(
      marketplace
        .connect(player1)
        .buy(2)
    ).to.be.revertedWith('Token not supported')

    // add ERC20 token to whitelist
    await marketplace.connect(admin).setWhitelistTokens([primaryToken.address])

    // set price
    await expect(marketplace.connect(admin).setPrice(2, 1000, primaryToken.address))
      .to.emit(marketplace, 'PriceChanged')
      .withArgs(2, 1000, primaryToken.address)

    // approve erc20 to marketplace to spend
    await primaryToken.connect(player1).approve(marketplace.address, 1000)

    await expect(
      marketplace
        .connect(player1)
        .buy(2)
    )
      .to.emit(marketplace, 'ItemSold')
      .withArgs(2, [2], admin.address, player1.address, 1000, 0, 0, nft.address)

    const ERC721owner = await nft.ownerOf(2)
    expect(ERC721owner).to.equal(player1.address)
  })

  it('can remove listing', async function () {
    await expect(marketplace.connect(admin).removeListing([3]))
      .to.emit(marketplace, 'ItemDelisted')
      .withArgs(3, [3], admin.address)

    const ERC721owner = await nft.ownerOf(3)
    expect(ERC721owner).to.equal(admin.address)
  })
})
