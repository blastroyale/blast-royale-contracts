import { Provider } from '@ethersproject/abstract-provider'
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers'
import { expect } from 'chai'
import { Contract, Contract, Signer } from 'ethers'
import { ethers } from 'hardhat'

const SIGNING_DOMAIN_NAME = 'LazyCS-Voucher'
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
   * Creates a new CSVoucher object and signs it using this LazyMinter's signing key.
   *
   * @param {ethers.BigNumber | number} amount the amount of CS
   * @param {address} minter the minter
   *
   * @returns {CSVoucher}
   */
  async createVoucher (amount: string, minter: any) {
    const voucher = { amount, minter }
    const domain = await this._signingDomain()
    const types = {
      CSVoucher: [
        { name: 'amount', type: 'uint256' },
        { name: 'minter', type: 'address' }
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

describe('Lazy mint CS', function () {
  let cs: Contract
  let admin: SignerWithAddress
  let player1: SignerWithAddress
  let player2: SignerWithAddress
  let treasury1: SignerWithAddress
  let treasury2: SignerWithAddress

  before('deploying', async () => {
    const signers = await ethers.getSigners()
    admin = signers[0]
    player1 = signers[1]
    player2 = signers[2]
    treasury1 = signers[3]
    treasury2 = signers[4]
  })

  it('Deploy Secondary Token', async function () {
    const CSToken = await ethers.getContractFactory('SecondaryToken')
    cs = await CSToken.deploy(
      'Craft Spice',
      '$CS',
      ethers.utils.parseEther('100000000'),
      admin.address
    )
    await cs.deployed()
  })

  it('Deploy lazyMint', async function () {
    const LazyMint = await ethers.getContractFactory('LazyCSMinter')
    lazyMint = await LazyMint.connect(admin).deploy(cs.address, admin.address)
    await lazyMint.deployed()
  })

  it('can redeem CS', async function () {
    // give minter role to the lazymint contract
    const minterRole = await cs.MINTER_ROLE()
    await cs.connect(admin).grantRole(minterRole, lazyMint.address)
    // create voucher
    const lazyminter = new LazyMinter({
      contract: lazyMint.address,
      signer: admin
    })
    const voucher1 = await lazyminter.createVoucher(
      '1000000000000000000',
      player1.address
    )
    await lazyMint.connect(player1).redeem(voucher1)
    const player1CSBalance = await cs.balanceOf(player1.address)
    expect(player1CSBalance).to.equal('1000000000000000000')
  })

  it('cannot redeem CS if the voucher is not signed by admin', async function () {
    // give minter role to the lazymint contract
    const minterRole = cs.MINTER_ROLE()
    await cs.connect(admin).grantRole(minterRole, lazyMint.address)
    // create voucher
    const lazyminter = new LazyMinter({
      contract: lazyMint.address,
      signer: player1
    })
    const voucher = await lazyminter.createVoucher(
      '1000000000000000000',
      player1.address
    )

    await expect(
      lazyMint
        .connect(player1)
        .redeem(voucher)
    ).to.be.revertedWith('Signature invalid or unauthorized')
  })

  it('owner can change admin', async function () {
    await lazyMint.connect(admin).setAdminAddress(player2.address)
    // create voucher
    const lazyminter = new LazyMinter({
      contract: lazyMint.address,
      signer: player2
    })
    const voucher = await lazyminter.createVoucher(
      '1000000000000000000',
      player2.address
    )

    const lazyminterAdmin = new LazyMinter({
      contract: lazyMint.address,
      signer: admin
    })

    const voucherAdmin = await lazyminterAdmin.createVoucher(
      '1000000000000000000',
      admin.address
    )

    await lazyMint.connect(player2).redeem(voucher)
    const player2CSBalance = await cs.balanceOf(player2.address)
    expect(player2CSBalance).to.equal('1000000000000000000')

    await expect(
      lazyMint
        .connect(admin)
        .redeem(voucherAdmin)
    ).to.be.revertedWith('Signature invalid or unauthorized')

    await lazyMint.connect(admin).setAdminAddress(admin.address)
  })
})
