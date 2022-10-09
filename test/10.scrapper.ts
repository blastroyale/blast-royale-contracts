/* eslint-disable node/no-missing-import */
import { expect } from 'chai'
import { BigNumber } from 'ethers'
import { ethers, network } from 'hardhat'
import { getContractArguments } from '../scripts/deploy/helper'

describe('Scrapping Contract', () => {
  let owner: any, addr1: any
  let bet: any
  let cs: any
  let scrapper: any

  // When level: 1, adjective: 9, rarity: 9, grade: 5
  const EXPECTED_VALUES = '2036'

  before(async () => {
    [owner, addr1] = await ethers.getSigners()
    // BlastEquipment NFT Deploying
    const BlastEquipmentToken = await ethers.getContractFactory(
      'BlastEquipmentNFT'
    )
    bet = await BlastEquipmentToken.connect(owner).deploy(
      'Blast Equipment',
      'BLT'
    )
    await bet.deployed()

    // CS Token deploying
    const secondaryTokenArgs = getContractArguments(
      network.name,
      'SecondaryToken'
    )
    const CraftToken = await ethers.getContractFactory('SecondaryToken')
    cs = await CraftToken.deploy(
      secondaryTokenArgs.name,
      secondaryTokenArgs.symbol,
      BigNumber.from(secondaryTokenArgs.supply),
      owner.address
    )
    await cs.deployed()
    await (
      await cs
        .connect(owner)
        .transfer(addr1.address, ethers.utils.parseEther('45000'))
    ).wait()

    // Scrapper Contract Deploying
    const scrapperFactory = await ethers.getContractFactory('Scrapper')
    scrapper = await scrapperFactory
      .connect(owner)
      .deploy(bet.address, cs.address)
    await scrapper.deployed()

    // Granting GAME ROLE role to Upgrader contract address
    const GAME_ROLE = await bet.GAME_ROLE()
    await bet.grantRole(GAME_ROLE, scrapper.address)

    // Granting MINTER ROLE to cs contract
    const MINTER_ROLE = await cs.MINTER_ROLE()
    await cs.grantRole(MINTER_ROLE, scrapper.address)

    // NFT equipment items minting
    const tx = await bet.connect(owner).safeMint(
      addr1.address,
      ['ipfs://111', 'ipfs://222'],
      [ethers.utils.keccak256('0x1000'), ethers.utils.keccak256('0x2000')],
      ['ipfs://111_real', 'ipfs://222_real'],
      [
        [0, 96, 9, 9, 5],
        [0, 96, 9, 9, 5]
      ]
    )
    await tx.wait()
  })

  it('Scrapping function test', async function () {
    const tokenId = 0

    const csPrice = await scrapper.connect(addr1).getCSPrice(tokenId)
    const EXPECTED_VALUE = ethers.utils.parseEther(EXPECTED_VALUES)

    expect(csPrice).to.eq(EXPECTED_VALUE.toString())

    await expect(scrapper.connect(addr1).scrap(tokenId)).to.revertedWith(
      'Not the owner'
    )

    await bet.connect(addr1).approve(scrapper.address, tokenId)

    await expect(scrapper.connect(addr1).scrap(tokenId))
      .to.emit(scrapper, 'Scrapped')
      .withArgs(tokenId, addr1.address, csPrice)
  })
})
