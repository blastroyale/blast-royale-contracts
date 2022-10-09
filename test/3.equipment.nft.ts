/* eslint-disable node/no-missing-import */
import { expect } from 'chai'
import { ethers } from 'hardhat'
import {
  deployPrimary,
  deploySecondary,
  deployBLST,
  mintBLST,
  getTimestampByBlockNumber
} from './helper'

describe('Blast Equipment NFT', function () {
  let owner: any
  let treasury: any
  let addr1: any
  let addr2: any
  let blst: any
  let primary: any
  let secondary: any

  beforeEach(async () => {
    [owner, treasury, addr1, addr2] = await ethers.getSigners()
    primary = await deployPrimary(owner, owner, treasury)
    secondary = await deploySecondary(owner)
    blst = await deployBLST(owner)
    await secondary
      .connect(owner)
      .claim(addr1.address, ethers.utils.parseEther('10000'))

    await primary
      .connect(treasury)
      .transfer(addr1.address, ethers.utils.parseEther('10000000'))

    await mintBLST(owner, blst, addr1, 3)
  })

  it("Check if attributes 'static, variable' is updated after minting", async () => {
    const [maxLevel, maxDurability, adjective, rarity, grade] =
      await blst.getStaticAttributes(0)

    expect(maxLevel).to.equal(5)
    expect(maxDurability).to.equal(0)
    expect(adjective).to.equal(0)
    expect(rarity).to.equal(0)
    expect(grade).to.equal(0)

    const [
      level,
      durabilityRestored,
      _durabilityPoint,
      ,
      repairCount,
      replicationCount
    ] = await blst.getAttributes(0)

    expect(level.toNumber()).to.equal(1)
    expect(durabilityRestored.toNumber()).to.equal(0)
    expect(_durabilityPoint.toNumber()).to.equal(0)
    expect(repairCount.toNumber()).to.equal(0)
    expect(replicationCount.toNumber()).to.equal(0)
  })

  it('Check if attributes is updated after safeMintReplicator', async () => {
    await blst
      .connect(owner)
      .safeMintReplicator(
        await addr2.getAddress(),
        'ipfs://999',
        ethers.utils.formatBytes32String('0x999'),
        'ipfs://real_999',
        [6, 1, 1, 1, 1]
      )

    const [maxLevel, maxDurability, adjective, rarity, grade] =
      await blst.getStaticAttributes(3)

    expect(maxLevel).to.equal(6)
    expect(maxDurability).to.equal(1)
    expect(adjective).to.equal(1)
    expect(rarity).to.equal(1)
    expect(grade).to.equal(1)
  })

  it('Check lastRepairTime & tokenURI after reveal', async () => {
    const tx = await blst.revealRealTokenURI(2)
    const repairTime = await getTimestampByBlockNumber(tx.blockNumber)

    const [, , , lastRepairTime, , ,] = await blst.getAttributes(2)
    expect(lastRepairTime.toNumber()).to.equal(repairTime)

    const tokenURI = await blst.tokenURI(2)
    expect(tokenURI).to.equal('ipfs://real_2')
  })

  it('Check setLevel function', async () => {
    await expect(blst.setLevel(0, 6)).revertedWith('Max level reached')

    await expect(blst.setLevel(0, 5)).to.emit(blst, 'AttributeUpdated')
    const [level, , , , , ,] = await blst.getAttributes(0)
    expect(level.toNumber()).to.equal(5)
  })

  it('Check setRepairCount function', async () => {
    await expect(blst.setRepairCount(0, 1)).to.emit(blst, 'AttributeUpdated')
    const [, , , , repairCount, ,] = await blst.getAttributes(0)
    expect(repairCount.toNumber()).to.equal(1)
  })

  it('Check setReplicationCount function', async () => {
    await expect(blst.setReplicationCount(0, 1)).to.emit(
      blst,
      'AttributeUpdated'
    )
    const [, , , , , replicationCount] = await blst.getAttributes(0)
    expect(replicationCount.toNumber()).to.equal(1)
  })

  it('Check setStaticAttributes function', async () => {
    await blst.setStaticAttributes(0, [6, 1, 1, 1, 1])

    const [maxLevel, maxDurability, adjective, rarity, grade] =
      await blst.getStaticAttributes(0)
    expect(maxLevel).to.equal(6)
    expect(maxDurability).to.equal(1)
    expect(adjective).to.equal(1)
    expect(rarity).to.equal(1)
    expect(grade).to.equal(1)
  })
})
