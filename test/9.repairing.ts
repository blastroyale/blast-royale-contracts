import { expect } from 'chai'
import { BigNumber } from 'ethers'
import { ethers, network } from 'hardhat'
import { deployPrimary, deploySecondary, deployBLST, mintBLST, deployRepairing } from './helper'

describe('Repairing Contract', () => {
  let owner: any
  let treasury: any
  let company: any
  let addr1: any
  let blst: any
  let primary: any
  let secondary: any
  let repairing: any

  beforeEach(async () => {
    [owner, treasury, company, addr1] = await ethers.getSigners()
    primary = await deployPrimary(owner, owner, owner)
    secondary = await deploySecondary(owner)
    blst = await deployBLST(owner)
    repairing = await deployRepairing(owner, blst.address, primary.address, secondary.address, treasury.address, company.address)

    // Granting GAME ROLE role to Upgrader contract address
    const GAME_ROLE = await blst.GAME_ROLE()
    await blst.grantRole(GAME_ROLE, repairing.address)

    // Granting MINTER ROLE to cs contract
    const MINTER_ROLE = await secondary.MINTER_ROLE()
    await secondary.grantRole(MINTER_ROLE, repairing.address)

    await primary
      .connect(owner)
      .transfer(addr1.address, ethers.utils.parseEther('1000'))

    await secondary
      .connect(owner)
      .claim(addr1.address, ethers.utils.parseEther('1000'))

    await mintBLST(owner, blst, addr1, 3)
  })

  it('Repair with cs Token', async () => {
    // Week 1. maxDurability: 96, durability: 1
    await network.provider.send('evm_increaseTime', [3600 * 24 * 7])
    await network.provider.send('evm_mine')
    let nftAttributes = await blst.getAttributes(0)
    expect(nftAttributes[2].toNumber()).to.eq(1)
    let repairPrice = await repairing.getRepairPrice(0)
    expect(repairPrice).to.gte(ethers.utils.parseEther('20'))

    // Week 2. maxDurability: 96, durability: 2
    await network.provider.send('evm_increaseTime', [3600 * 24 * 7])
    await network.provider.send('evm_mine')
    nftAttributes = await blst.getAttributes(0)
    expect(nftAttributes[2].toNumber()).to.eq(2)
    repairPrice = await repairing.getRepairPrice(0)
    expect(repairPrice).to.gte(ethers.utils.parseEther('113'))

    // We do Repair on Week 2. It gives us maxDurability: 96, durability: 0, durabilityRestored: 2
    await secondary
      .connect(addr1)
      .approve(repairing.address, ethers.utils.parseEther('114'))
    await repairing.connect(addr1).repair(0)

    nftAttributes = await blst.getAttributes(0)
    expect(nftAttributes[1].toNumber()).to.eq(2)
    expect(nftAttributes[2].toNumber()).to.eq(0)
    repairPrice = await repairing.getRepairPrice(0)
    expect(repairPrice.toNumber()).to.eq(0)

    // Week 3, maxDurability: 96, durability: 1, durabilityRestored: 2
    await network.provider.send('evm_increaseTime', [3600 * 24 * 7])
    await network.provider.send('evm_mine')
    nftAttributes = await blst.getAttributes(0)
    expect(nftAttributes[2].toNumber()).to.eq(1)
    repairPrice = await repairing.getRepairPrice(0)
    expect(repairPrice).to.gte(ethers.utils.parseEther('46'))

    // Week 95, maxDurability: 96, durability: 93, durabilityRestored: 2. On this week the item becomes unusable in game.
    await network.provider.send('evm_increaseTime', [3600 * 24 * 7 * 92])
    await network.provider.send('evm_mine')
    nftAttributes = await blst.getAttributes(0)
    expect(nftAttributes[2].toNumber()).to.eq(93)
    repairPrice = await repairing.getRepairPrice(0)
    expect(repairPrice).to.gte(ethers.utils.parseEther('3867388'))

    // Week 100, maxDurability: 96, durability: 96, durabilityRestored: 2
    await network.provider.send('evm_increaseTime', [3600 * 24 * 7 * 1])
    await network.provider.send('evm_mine')
    nftAttributes = await blst.getAttributes(0)
    expect(nftAttributes[2].toNumber()).to.eq(94)
    repairPrice = await repairing.getRepairPrice(0)
    expect(repairPrice).to.gte(ethers.utils.parseEther('3973360'))
  })

  it('Repair with BLST Token', async () => {
    await network.provider.send('evm_increaseTime', [3600 * 24 * 7])
    await network.provider.send('evm_mine')
    let nftAttributes = await blst.getAttributes(0)
    expect(nftAttributes[2].toNumber()).to.eq(1)
    let repairPrice = await repairing.getRepairPriceBLST(0)
    expect(repairPrice).to.gte(ethers.utils.parseEther('20'))

    // Week 9. maxDurability: 96, durability: 9
    await network.provider.send('evm_increaseTime', [3600 * 24 * 7 * 8])
    await network.provider.send('evm_mine')

    repairPrice = await repairing.getRepairPriceBLST(0)
    await primary
      .connect(addr1)
      .approve(repairing.address, repairPrice.sub(BigNumber.from('100')))
    await expect(repairing.connect(addr1).repair(0)).to.revertedWith(
      'ERC20: insufficient allowance'
    )
    await primary.connect(addr1).approve(repairing.address, repairPrice)
    await expect(repairing.connect(addr1).repair(0)).to.emit(
      repairing,
      'Repaired'
    )

    // We do Repair on Week 9. It gives us maxDurability: 96, durability: 0, durabilityRestored: 9
    await network.provider.send('evm_increaseTime', [3600 * 24 * 7])
    await network.provider.send('evm_mine')
    nftAttributes = await blst.getAttributes(0)
    expect(nftAttributes[1].toNumber()).to.eq(9)
    expect(nftAttributes[2].toNumber()).to.eq(1)
  })
})
