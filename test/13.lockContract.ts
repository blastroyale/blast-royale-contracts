import { expect } from 'chai'
import { Contract } from 'ethers'
import { ethers } from 'hardhat'

describe('Lock contract', function () {
  let nft: Contract
  let lockContract: Contract
  let erc1155: Contract
  let admin: any

  before('deploying', async () => {
    const signers = await ethers.getSigners()
    admin = signers[0]
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

  it('Deploys lock contract', async function () {
    const LockContract = await ethers.getContractFactory('LockContract')
    lockContract = await LockContract.connect(admin).deploy()
    await lockContract.deployed()
  })

  it('can burn ERC721', async function () {
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

    await lockContract.connect(admin).addWhitelistedBurnableContract(nft.address)

    await nft.connect(admin).setApprovalForAll(lockContract.address, true)

    await expect(
      lockContract
        .connect(admin)
        .burnERC721(nft.address, [0, 1])
    )
      .to.emit(lockContract, 'ERC721Burnt')
      .withArgs(admin.address, nft.address, [0, 1])

    await expect(
      nft.ownerOf(0)
    ).to.be.reverted

    await expect(
      nft.ownerOf(1)
    ).to.be.reverted
  })

  it('can lock ERC1155', async function () {
    await erc1155.connect(admin).mintBatch(admin.address, [0, 1], [1, 2], '0x00')

    let amount = await erc1155.balanceOfBatch([admin.address, admin.address], [0, 1])

    expect(
      amount[0].toString()
    ).to.equal('1')

    expect(
      amount[1].toString()
    ).to.equal('2')

    await lockContract.connect(admin).addWhitelistedContract(erc1155.address)

    await erc1155.connect(admin).setApprovalForAll(lockContract.address, true)

    await expect(
      lockContract
        .connect(admin)
        .lockERC1155(erc1155.address, [0, 1], [1, 1])
    )
      .to.emit(lockContract, 'ERC1155Locked')
      .withArgs(admin.address, erc1155.address, [0, 1], [1, 1])

    amount = await erc1155.balanceOfBatch([lockContract.address, lockContract.address], [0, 1])

    expect(
      amount[0].toString()
    ).to.equal('1')

    expect(
      amount[1].toString()
    ).to.equal('1')
  })

  it('can withdraw ERC1155', async function () {
    await expect(
      lockContract
        .connect(admin)
        .withdrawERC1155(erc1155.address, admin.address, [0, 1], [1, 1])
    )
      .to.emit(lockContract, 'NFTWithdraw')
      .withArgs(admin.address, erc1155.address, [0, 1], [1, 1])

    const amount = await erc1155.balanceOfBatch([lockContract.address, lockContract.address], [0, 1])

    expect(
      amount[0].toString()
    ).to.equal('0')

    expect(
      amount[1].toString()
    ).to.equal('0')

    const adminAmount = await erc1155.balanceOfBatch([admin.address, admin.address], [0, 1])

    expect(
      adminAmount[0].toString()
    ).to.equal('1')

    expect(
      adminAmount[1].toString()
    ).to.equal('2')
  })
})
