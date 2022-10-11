/**
 * Allocation of 15% of total supply (76,800,000 $BLST)
 * 4% unlocked at the TGE, then 6 months cliff, then unlock 4% more each month
 */
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers'
import { expect } from 'chai'
import { ethers, network } from 'hardhat'
// eslint-disable-next-line node/no-missing-import
import { PrimaryToken, TokenVesting } from '../../typechain'

describe('TokenVesting', function () {
  let owner: SignerWithAddress,
    addr1: SignerWithAddress,
    treasury: SignerWithAddress
  let blt: PrimaryToken
  let vesting: TokenVesting
  beforeEach(async () => {
    [owner, addr1, treasury] = await ethers.getSigners()

    // Blast Token vesting
    const BlastToken = await ethers.getContractFactory('PrimaryToken')
    blt = await BlastToken.connect(owner).deploy(
      'Blast Royale',
      '$BLT',
      owner.address,
      treasury.address,
      ethers.utils.parseEther('512000000')
    )
    await blt.deployed()

    const TokenVesting = await ethers.getContractFactory('TokenVesting')
    vesting = await TokenVesting.connect(owner).deploy(blt.address)
    await vesting.deployed()
  })

  it('Test TokenVesting', async function () {
    // Transfer blast Token to vesting contract
    const transferTx = await blt
      .connect(treasury)
      .transfer(vesting.address, ethers.utils.parseEther('76800000'))
    await transferTx.wait()

    // Friday, May 20, 2022 4:24:52 PM. It's TGE
    // https://www.epochconverter.com/
    const startTimestamp = new Date().getTime()
    const cliffDurationInSeconds = 3600 * 24 * 30 * 6 // 6 months
    const durationInSeconds = 3600 * 24 * 30 * 24 // 24 months
    const createTx = await vesting.createVestingSchedule(
      addr1.address,
      startTimestamp,
      cliffDurationInSeconds,
      durationInSeconds,
      ethers.utils.parseEther('3072000'), // 4% unlocking at TGE
      ethers.utils.parseEther('73728000'),
      true
    )
    await createTx.wait()

    const scheduleId = await vesting.computeVestingScheduleIdForAddressAndIndex(
      addr1.address,
      0
    )

    // 1 month forward
    await network.provider.send('evm_increaseTime', [3600 * 24 * 30])
    await network.provider.send('evm_mine')

    const amount = await vesting.computeReleasableAmount(scheduleId)
    expect(amount).to.eq(ethers.utils.parseEther('3072000'))

    const releaseTx = await vesting
      .connect(addr1)
      .release(scheduleId, ethers.utils.parseEther('3072000'))
    await releaseTx.wait()

    // 6 month forward
    await network.provider.send('evm_increaseTime', [3600 * 24 * 30 * 5])
    await network.provider.send('evm_mine')

    const amount1 = await vesting.computeReleasableAmount(scheduleId)
    const releaseTx1 = await vesting
      .connect(addr1)
      .release(scheduleId, amount1)
    await releaseTx1.wait()

    const schedule = await vesting.getVestingSchedule(scheduleId)
    expect(schedule.released).to.eq(
      amount1.add(ethers.utils.parseEther('3072000'))
    )

    // 24 month forward
    await network.provider.send('evm_increaseTime', [3600 * 24 * 30 * 25])
    await network.provider.send('evm_mine')

    const amount2 = await vesting.computeReleasableAmount(scheduleId)
    const releaseTx2 = await vesting
      .connect(addr1)
      .release(scheduleId, amount2)
    await releaseTx2.wait()

    const schedule2 = await vesting.getVestingSchedule(scheduleId)
    expect(schedule2.released).to.eq(ethers.utils.parseEther('3072000'))
  })
})
