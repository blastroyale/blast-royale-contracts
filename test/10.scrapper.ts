import { expect } from 'chai'
import { ethers } from 'hardhat'
import { deployPrimary, deploySecondary, deployBLST, deployScrapper, mintBLST } from './helper'

describe('Scrapping Contract', () => {
  let owner: any
  let addr1: any
  let addr2: any
  let blst: any
  let primary: any
  let secondary: any
  let scrapper: any

  // When level: 1, adjective: 9, rarity: 9, grade: 5
  const EXPECTED_VALUES = '2036'

  beforeEach(async () => {
    [owner, addr1, addr2] = await ethers.getSigners()
    primary = await deployPrimary(owner, owner, owner)
    secondary = await deploySecondary(owner)
    blst = await deployBLST(owner)
    scrapper = await deployScrapper(owner, blst.address, secondary.address)

    // Granting GAME ROLE role to Upgrader contract address
    const GAME_ROLE = await blst.GAME_ROLE()
    await blst.grantRole(GAME_ROLE, scrapper.address)

    // Granting MINTER ROLE to cs contract
    const MINTER_ROLE = await secondary.MINTER_ROLE()
    await secondary.grantRole(MINTER_ROLE, scrapper.address)

    await primary
      .connect(owner)
      .transfer(addr1.address, ethers.utils.parseEther('1000'))

    await mintBLST(owner, blst, addr1, 1)
  })

  it('Scrapping function test', async function () {
    const tokenId = 0

    const csPrice = await scrapper.getCSPrice(tokenId)
    const EXPECTED_VALUE = ethers.utils.parseEther(EXPECTED_VALUES)

    expect(csPrice).to.eq(EXPECTED_VALUE.toString())

    await expect(scrapper.connect(addr2).scrap(tokenId)).to.revertedWith(
      'Scrapper: Not owner of token'
    )

    await blst.connect(addr1).approve(scrapper.address, tokenId)

    await expect(scrapper.connect(addr1).scrap(tokenId))
      .to.emit(scrapper, 'Scrapped')
      .withArgs(tokenId, addr1.address, csPrice)

    const balance = await secondary.balanceOf(addr1.address)
    expect(balance).to.eq(EXPECTED_VALUE.toString())
  })
})
