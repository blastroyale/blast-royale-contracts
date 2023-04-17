import { Provider } from '@ethersproject/abstract-provider'
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers'
import { expect } from 'chai'
import { Contract, Signer } from 'ethers'
import { ethers } from 'hardhat'

import {
  deployBLST,
  deployReplicator,
  deployPrimary,
  deploySecondary
} from './helper'

const SIGNING_DOMAIN_NAME = 'LazyReplicate-Voucher'
const SIGNING_DOMAIN_VERSION = '1'

let lazyMint: Contract

type LazyMintProps = {
  contract: string,
  signer: any
}

class LazyMinter {
  contract: any
  signer: any
  _domain: null | any
  /**
   * Create a new LazyMinter targeting a deployed instance of the LazyNFT contract.
   *
   * @param {Object} options
   * @param {ethers.Contract} contract an ethers Contract that's wired up to the deployed contract
   * @param {ethers.Signer} signer a Signer whose account is authorized to mint NFTs on the deployed contract
   */
  constructor ({ contract, signer } : LazyMintProps) {
    this.contract = contract
    this.signer = signer
  }

  /**
   * Creates a new ReplicateVoucher object and signs it using this LazyMinter's signing key.
   *
   * @param {ethers.BigNumber | number} amount the amount of CS
   * @param {address} minter the minter
   *
   * @returns {ReplicateVoucher}
   */
  async createVoucher (id: number, hashString: string, realUri: string, p1: number, p2: number, maxLevel: number, maxDurability: number, maxReplication: number, adjective: number, rarity: number, grade: number, maticAmount: string) {
    const voucher = { id, hashString, realUri, p1, p2, maxLevel, maxDurability, maxReplication, adjective, rarity, grade, maticAmount }
    const domain = await this._signingDomain()
    const types = {
      ReplicateVoucher: [
        { name: 'id', type: 'uint256' },
        { name: 'hashString', type: 'string' },
        { name: 'realUri', type: 'string' },
        { name: 'p1', type: 'uint256' },
        { name: 'p2', type: 'uint256' },
        { name: 'maxLevel', type: 'uint8' },
        { name: 'maxDurability', type: 'uint8' },
        { name: 'maxReplication', type: 'uint8' },
        { name: 'adjective', type: 'uint8' },
        { name: 'rarity', type: 'uint8' },
        { name: 'grade', type: 'uint8' },
        { name: 'maticAmount', type: 'string' }
      ]
    }
    const signature = await this.signer._signTypedData(domain, types, voucher)
    return {
      ...voucher,
      signature
    }
  }

  /**
   * @private
   * @returns {object} the EIP-721 signing domain, tied to the chainId of the signer
   */
  async _signingDomain () {
    if (this._domain != null) {
      return this._domain
    }
    // const chainId = await this.contract.getChainID();
    this._domain = {
      name: SIGNING_DOMAIN_NAME,
      version: SIGNING_DOMAIN_VERSION,
      verifyingContract: lazyMint.address,
      chainId: 31337
    }
    return this._domain
  }
}

describe('Lazy replicate', function () {
  let admin: SignerWithAddress
  let player1: SignerWithAddress
  let player2: SignerWithAddress
  let treasury1: SignerWithAddress
  let treasury2: SignerWithAddress
  let blst: any
  let primary: any
  let secondary: any
  let replicator: any

  before('deploying', async () => {
    const signers = await ethers.getSigners()
    admin = signers[0]
    player1 = signers[1]
    player2 = signers[2]
    treasury1 = signers[3]
    treasury2 = signers[4]
  })

  it('Deploy Equipment NFTs', async function () {
    blst = await deployBLST(admin)
  })

  it('Deploy Primary', async function () {
    primary = await deployPrimary(admin, admin, admin)
  })

  it('Deploy Secondary', async function () {
    secondary = await deploySecondary(admin)
    await secondary.connect(admin).claim(player1.address, '999999999999999999999999999999')
  })

  it('Deploy Replicator', async function () {
    replicator = await deployReplicator(admin, blst.address, primary.address, secondary.address, admin.address, admin.address)
  })

  it('Deploy lazyReplicate', async function () {
    const LazyReplicate = await ethers.getContractFactory('LazyReplicate')
    lazyMint = await LazyReplicate.connect(admin).deploy(replicator.address, admin.address, treasury1.address)
    await lazyMint.deployed()
  })

  it('can redeem CS', async function () {
    // give admin role to the lazymint contract
    const adminRole = await replicator.DEFAULT_ADMIN_ROLE()
    const replicatorRole = await blst.REPLICATOR_ROLE()
    const gameRole = await blst.GAME_ROLE()
    await replicator.connect(admin).grantRole(adminRole, lazyMint.address)
    await blst.connect(admin).grantRole(replicatorRole, replicator.address)
    await blst.connect(admin).grantRole(gameRole, replicator.address)
    // mint NFTs
    await blst.connect(admin).safeMint(player1.address, [ethers.utils.formatBytes32String('0x999'), ethers.utils.formatBytes32String('0x999')], ['ipfs://real_999', 'ipfs://real_999'], [
      [5, 0, 3, 0, 0, 0],
      [5, 0, 3, 0, 0, 0]
    ])
    await blst.connect(admin).grantRole(adminRole, lazyMint.address)
    await blst.connect(admin).grantRole(adminRole, lazyMint.address)
    await secondary.connect(player1).approve(replicator.address, '999999999999999999999999999999')
    await replicator.connect(admin).flipIsUsingMatic()
    // create voucher
    const lazyminter = new LazyMinter({
      contract: lazyMint.address,
      signer: admin
    })

    const voucher1 = await lazyminter.createVoucher(
      0,
      '8d7d4991d2fb7363c6bc337665451841cb9374e341b100172fd9cfacd445eb9d',
      'ipfs://real_999',
      0,
      1,
      1,
      1,
      3,
      1,
      1,
      1,
      '10000000000000000'
    )
    console.log('admindddd', admin.address)
    await lazyMint.connect(player1).redeem(voucher1, { value: '10000000000000000' })
    const player1NFTBalance = await blst.balanceOf(player1.address)
    expect(player1NFTBalance).to.equal('3')
  })

  it('cannot redeem twice using the same voucher', async function () {
    // create voucher
    const lazyminter = new LazyMinter({
      contract: lazyMint.address,
      signer: admin
    })
    const voucher10 = await lazyminter.createVoucher(
      0,
      '8d7d4991d2fb7363c6bc337665451841cb9374e341b100172fd9cfacd445eb9d',
      'ipfs://real_999',
      0,
      1,
      1,
      1,
      3,
      1,
      1,
      1,
      '10000000000000000'
    )
    await expect(
      lazyMint
        .connect(player1)
        .redeem(voucher10, { value: '10000000000000000' })
    ).to.be.revertedWith('voucher had been used')
    const player1NFTBalance = await blst.balanceOf(player1.address)
    expect(player1NFTBalance).to.equal('3')
  })

  it('cannot redeem CS if the voucher is not signed by admin', async function () {
    // create voucher
    const lazyminter = new LazyMinter({
      contract: lazyMint.address,
      signer: player1
    })
    const voucher = await lazyminter.createVoucher(
      1,
      '8d7d4991d2fb7363c6bc337665451841cb9374e341b100172fd9cfacd445eb9d',
      'ipfs://real_999',
      0,
      1,
      1,
      1,
      3,
      1,
      1,
      1,
      '10000000000000000'
    )

    await expect(
      lazyMint
        .connect(player1)
        .redeem(voucher, { value: '10000000000000000' })
    ).to.be.revertedWith('Signature invalid or unauthorized')
  })

  it('cannot redeem CS if the matic amount is wrong', async function () {
    // create voucher
    const lazyminter = new LazyMinter({
      contract: lazyMint.address,
      signer: player1
    })
    const voucher = await lazyminter.createVoucher(
      2,
      '8d7d4991d2fb7363c6bc337665451841cb9374e341b100172fd9cfacd445eb9d',
      'ipfs://real_999',
      0,
      1,
      1,
      1,
      3,
      1,
      1,
      1,
      '10000000000000000'
    )

    await expect(
      lazyMint
        .connect(player1)
        .redeem(voucher, { value: '9000000000000000' })
    ).to.be.revertedWith('correct amount of matic is required')
  })
})
