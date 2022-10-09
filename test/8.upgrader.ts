/* eslint-disable node/no-missing-import */
import { expect } from 'chai'
import { BigNumber } from 'ethers'
import { ethers } from 'hardhat'
import {
  deployPrimary,
  deploySecondary,
  deployBLST,
  deployUpgrader,
  mintBLST
} from './helper'

describe('Upgrader Contract', () => {
  let owner: any
  let treasury: any
  let company: any
  let addr1: any
  let blst: any
  let primary: any
  let secondary: any
  let upgrader: any

  // Rarity => [Adjective => Grade => [level => [bltPrice, csPrice]]]
  const EXPECTED_VALUES: any = [
    [
      [
        {
          1: [5.22, 174], // Common, Regular, I, 1
          5: [5.33, 191], // Common, Regular, I, 5
          10: [5.46, 213] // Common, Regular, I, 10
        },
        {},
        {},
        {},
        {
          1: [3, 100], // Common, Regular, V, 1
          5: [3.06, 110], // Common, Regular, V, 5
          10: [3.14, 122] // Common, Regular, V, 10
        }
      ]
    ],
    [
      [
        {
          1: [6.97, 313], // Common, Posh, I, 1
          5: [7.11, 345], // Common, Posh, I, 5
          10: [7.29, 384] // Common, Posh, I, 10
        },
        {},
        {},
        {},
        {
          1: [3, 100], // Common, Regular, V, 1
          5: [3.06, 110], // Common, Regular, V, 5
          10: [3.14, 122] // Common, Regular, V, 10
        }
      ]
    ]
  ]

  const getExpectedValue = async (tokenId: number): Promise<Array<number>> => {
    const [level] = await blst.getAttributes(tokenId)
    const [, , adjective, rarity, grade] = await blst.getStaticAttributes(
      tokenId
    )

    return EXPECTED_VALUES[rarity][adjective][grade][level.toNumber()]
  }

  before(async () => {
    [owner, treasury, company, addr1] = await ethers.getSigners()
    primary = await deployPrimary(owner, owner, owner)
    secondary = await deploySecondary(owner)
    blst = await deployBLST(owner)
    upgrader = await deployUpgrader(
      owner,
      blst.address,
      primary.address,
      secondary.address,
      treasury.address,
      company.address
    )

    await primary
      .connect(owner)
      .transfer(addr1.address, ethers.utils.parseEther('14'))

    await secondary
      .connect(owner)
      .claim(addr1.address, ethers.utils.parseEther('45000'))

    await mintBLST(owner, blst, addr1, 3)

    // Granting GAME ROLE role to Upgrader contract address
    const GAME_ROLE = await blst.GAME_ROLE()
    await blst.grantRole(GAME_ROLE, upgrader.address)
  })

  it('Upgrade function test', async function () {
    const tokenId = 0
    const BLT_TYPE = 0
    const CS_TYPE = 1

    const bltPrice = await upgrader
      .connect(addr1)
      .getRequiredPrice(BLT_TYPE, tokenId)
    const csPrice = await upgrader
      .connect(addr1)
      .getRequiredPrice(CS_TYPE, tokenId)
    const _prices = await getExpectedValue(tokenId)

    expect(bltPrice).to.eq(ethers.utils.parseEther(_prices[0].toString()))
    expect(csPrice).to.eq(ethers.utils.parseEther(_prices[1].toString()))

    const [currentLevel, , , , ,] = await blst.getAttributes(tokenId)

    // Approve token
    await (
      await secondary
        .connect(addr1)
        .approve(upgrader.address, csPrice.sub(BigNumber.from('1')))
    ).wait()

    // Upgrade
    await expect(upgrader.connect(addr1).upgrade(tokenId)).to.revertedWith(
      'ERC20: insufficient allowance'
    )

    await (
      await secondary.connect(addr1).approve(upgrader.address, csPrice)
    ).wait()
    await (
      await primary.connect(addr1).approve(upgrader.address, bltPrice)
    ).wait()

    await expect(upgrader.connect(addr1).upgrade(tokenId))
      .to.emit(upgrader, 'LevelUpgraded')
      .withArgs(tokenId, addr1.address, 2)

    const [newLevel, , , , ,] = await blst.getAttributes(tokenId)

    expect(newLevel).to.eq(currentLevel.add(1))
  })
})
