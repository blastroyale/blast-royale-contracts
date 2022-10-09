import { expect } from 'chai'
import { ethers } from 'hardhat'

describe('Blast Royale Token', function () {
  let owner: any
  let addr1: any
  let treasury: any
  let blt: any
  before('deploying', async () => {
    const signers = await ethers.getSigners();
    [owner, addr1, treasury] = signers
  })
  it('Mint Primary Token', async function () {
    const BlastToken = await ethers.getContractFactory('PrimaryToken')
    blt = await BlastToken.deploy(
      'Blast Royale',
      '$BLT',
      owner.address,
      treasury.address,
      ethers.utils.parseEther('512000000')
    )
    await blt.deployed()
    // check if it can mint the correct amount
    expect(await blt.balanceOf(treasury.address)).to.equal(
      ethers.utils.parseEther('512000000')
    )
  })

  it('Pause Token Transfer', async function () {
    // only owner can pause
    await expect(blt.connect(addr1).pause()).to.be.revertedWith(
      'Ownable: caller is not the owner'
    )

    await blt.connect(owner).pause()
    // token transfer not allowed when the contract is paused
    await expect(
      blt
        .connect(treasury)
        .transfer(addr1.address, ethers.utils.parseEther('100'))
    ).to.be.revertedWith('ERC20Pausable: token transfer while paused')
  })

  it('Unpause Token Transfer', async function () {
    // only owner can unpause
    await expect(blt.connect(addr1).unpause()).to.be.revertedWith(
      'Ownable: caller is not the owner'
    )

    await blt.connect(owner).unpause()

    await blt
      .connect(treasury)
      .transfer(addr1.address, ethers.utils.parseEther('100'))
    // allow transfer of token when it's unpaused
    expect(await blt.balanceOf(addr1.address)).to.equal(
      ethers.utils.parseEther('100')
    )
  })
})
