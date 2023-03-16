import { expect } from 'chai'
import { providers } from 'ethers'
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
  let blst: any
  let primary: any
  let secondary: any
  let replicator: any

  beforeEach(async () => {
    [owner, treasury, company, addr1] = await ethers.getSigners()
    primary = await deployPrimary(owner, owner, treasury)
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

    await secondary
      .connect(owner)
      .claim(addr1.address, ethers.utils.parseEther('10000'))

    await primary
      .connect(treasury)
      .transfer(addr1.address, ethers.utils.parseEther('10000000'))

    await mintBLST(owner, blst, addr1, 3)

    const DEFAULT_ADMIN_ROLE = ethers.utils.hexZeroPad('0x00', 32)
    await replicator.grantRole(DEFAULT_ADMIN_ROLE, addr1.address)

    // Granting Replicator role to replicator contract address
    const REPLICATOR_ROLE = await blst.REPLICATOR_ROLE()
    await blst.grantRole(REPLICATOR_ROLE, replicator.address)

    // Granting Replicator role to replicator contract address
    const REVEAL_ROLE = await blst.REVEAL_ROLE()
    await blst.grantRole(REVEAL_ROLE, replicator.address)
  })

  it('Replicate function test', async function () {
    // Approve token
    const approveTx1 = await secondary
      .connect(addr1)
      .approve(replicator.address, ethers.utils.parseEther('45000'))
    await approveTx1.wait()
    const approveTx2 = await primary
      .connect(addr1)
      .approve(replicator.address, ethers.utils.parseEther('14'))
    await approveTx2.wait()

    const eggMetadataUrl =
      'https://flgmarketplacestorage.z33.web.core.windows.net/nftmetadata/replicator/egg_metadata_preview.json'
    const realMetadataUrl =
      'https://flgmarketplacestorage.z33.web.core.windows.net/nftmetadata/0/1/8d7d4991d2fb7363c6bc337665451841cb9374e341b100172fd9cfacd445eb9d.json'
    const hash =
      '8d7d4991d2fb7363c6bc337665451841cb9374e341b100172fd9cfacd445eb9d'

    // console.log(ethers.utils.formatBytes32String(hash));
    // console.log(
    //   ethers.utils.parseBytes32String(ethers.utils.formatBytes32String(hash))
    // );
    // await (
    //   await bet.connect(addr1).approve(replicator.address, 0)
    // ).wait();
    // await (
    //   await bet.connect(addr1).approve(replicator.address, 1)
    // ).wait();

    // Signature generation with EIP712
    const block = await providers.getDefaultProvider().getBlock('latest')
    const blockTimestamp = block.timestamp
    const deadline = blockTimestamp + 3600
    const nonce = await replicator.nonces(addr1.address)

    const signature = await owner._signTypedData(
      // Domain
      {
        name: 'REPLICATOR',
        version: '1.0.0',
        chainId: 31337,
        verifyingContract: replicator.address
      },
      // Types
      {
        REPLICATOR: [
          { name: 'sender', type: 'address' },
          { name: 'uri', type: 'string' },
          { name: 'hash', type: 'string' },
          { name: 'realUri', type: 'string' },
          { name: 'p1', type: 'uint256' },
          { name: 'p2', type: 'uint256' },
          { name: 'nonce', type: 'uint256' },
          { name: 'deadline', type: 'uint256' }
        ]
      },
      // Value
      {
        sender: addr1.address,
        uri: eggMetadataUrl,
        hash: hash,
        realUri: realMetadataUrl,
        p1: 0,
        p2: 1,
        nonce: nonce.toNumber(),
        deadline: deadline
      }
    )

    // Replicate in Replicator Contract
    await expect(
      replicator
        .connect(addr1)
        .replicate(
          eggMetadataUrl + '123',
          hash,
          realMetadataUrl,
          0,
          1,
          deadline,
          signature
        )
    ).revertedWith('Replicator:Invalid Signature')
    await expect(
      replicator
        .connect(addr1)
        .replicate(
          eggMetadataUrl,
          hash,
          realMetadataUrl + '1',
          0,
          1,
          deadline,
          signature
        )
    ).revertedWith('Replicator:Invalid Signature')

    // Expecting event emitted
    await expect(
      replicator
        .connect(owner)
        .replicate(addr1.address, eggMetadataUrl, hash, realMetadataUrl, 0, 1, {
          maxLevel: 0,
          maxDurability: 0,
          adjective: 0,
          rarity: 0,
          grade: 0
        })
    ).to.emit(replicator, 'Replicated')

    // There should be backend logic here after emitting replicated event
    // Will simulate how it works

    // const replicateTxFrom = await bet
    //   .connect(addr1)
    //   .replicate(0, 1);
    // await replicateTxFrom.wait();

    expect(await primary.balanceOf(company.address)).to.eq(
      ethers.utils.parseEther('10.5')
    )
    expect(await primary.balanceOf(treasury.address)).to.eq(
      ethers.utils.parseEther('3.5')
    )

    expect(await blst.tokenURI(2)).to.eq(eggMetadataUrl)

    // Time increase to test morphTo function
    await network.provider.send('evm_increaseTime', [3600 * 24 * 6])
    await network.provider.send('evm_mine')

    // Executing morphTo function
    const morphTx = await replicator.connect(addr1).morph(2)
    await morphTx.wait()

    expect(await blst.tokenURI(2)).to.eq(realMetadataUrl)
  })
})
