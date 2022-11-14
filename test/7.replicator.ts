import { expect } from 'chai'
import { ethers, network } from 'hardhat'
import {
  deployPrimary,
  deploySecondary,
  deployBLST,
  deployReplicator,
  mintBLST
} from './helper'

describe('Replicator Contract', () => {
  let owner: any
  let treasury: any
  let company: any
  let addr1: any
  let addr2: any
  let blst: any
  let primary: any
  let secondary: any
  let replicator: any

  beforeEach(async () => {
    [owner, treasury, company, addr1, addr2] = await ethers.getSigners()
    primary = await deployPrimary(owner, owner, owner)
    secondary = await deploySecondary(owner)
    blst = await deployBLST(owner)
    replicator = await deployReplicator(
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

    // Granting Replicator role to replicator contract address
    const REPLICATOR_ROLE = await blst.REPLICATOR_ROLE()
    await blst.grantRole(REPLICATOR_ROLE, replicator.address)

    // Granting Replicator role to replicator contract address
    const REVEAL_ROLE = await blst.REVEAL_ROLE()
    await blst.grantRole(REVEAL_ROLE, replicator.address)
  })

  it('Replicate function test', async function () {
    // Approve primary and secondary token
    await primary
      .connect(addr1)
      .approve(replicator.address, ethers.utils.parseEther('14'))
    await secondary
      .connect(addr1)
      .approve(replicator.address, ethers.utils.parseEther('45000'))

    const eggMetadataUrl = 'https://static.blastroyale.com/previewMetadata.json'
    const realMetadataUrl =
      'nftmetadata/0/1/8d7d4991d2fb7363c6bc337665451841cb9374e341b100172fd9cfacd445eb9d.json'
    const hash =
      '8d7d4991d2fb7363c6bc337665451841cb9374e341b100172fd9cfacd445eb9d'

    // Expecting event emitted
    await expect(
      replicator
        .connect(addr2)
        .replicate(hash, realMetadataUrl, 0, 1, {
          maxLevel: 6,
          maxDurability: 0,
          maxReplication: 3,
          adjective: 0,
          rarity: 0,
          grade: 0
        })
    ).to.revertedWith(
      `AccessControl: account ${addr2.address.toLowerCase()} is missing role 0x0000000000000000000000000000000000000000000000000000000000000000`
    )

    await expect(
      replicator
        .connect(owner)
        .replicate(hash, realMetadataUrl, 0, 1, {
          maxLevel: 6,
          maxDurability: 0,
          maxReplication: 3,
          adjective: 0,
          rarity: 0,
          grade: 0
        })
    ).to.emit(replicator, 'Replicated')

    expect(await primary.balanceOf(company.address)).to.eq(
      ethers.utils.parseEther('10.5')
    )
    expect(await primary.balanceOf(treasury.address)).to.eq(
      ethers.utils.parseEther('3.5')
    )

    expect(await blst.tokenURI(3)).to.eq(eggMetadataUrl)

    // Time increase to test morphTo function
    await network.provider.send('evm_increaseTime', [3600 * 24 * 600])
    await network.provider.send('evm_mine')

    // Executing morphTo function
    const morphTx = await replicator.connect(addr1).morph(3)
    await morphTx.wait()

    expect(await blst.tokenURI(3)).to.eq('https://static.blastroyale.com/nftmetadata/0/1/8d7d4991d2fb7363c6bc337665451841cb9374e341b100172fd9cfacd445eb9d.json')
  })
})
