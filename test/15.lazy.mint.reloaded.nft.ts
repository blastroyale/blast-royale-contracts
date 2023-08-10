import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers'
import { expect } from 'chai'
import { Contract } from 'ethers'
import { ethers } from 'hardhat'
import {
  signTypedData,
  SignTypedDataVersion
} from '@metamask/eth-sig-util'

let lazyMint: Contract

type LazyMintProps = {
  contract: string,
  privateKey: any
}

class LazyMinter {
  contract: any
  privateKey: any
  _domain: null | any
  /**
   * Create a new LazyMinter targeting a deployed instance of the LazyNFT contract.
   *
   * @param {Object} options
   * @param {ethers.Contract} contract an ethers Contract that's wired up to the deployed contract
   * @param {ethers.Signer} signer a Signer whose account is authorized to mint NFTs on the deployed contract
   */
  constructor ({ contract, privateKey } : LazyMintProps) {
    this.contract = contract
    this.privateKey = privateKey
  }

  async createVoucher (voucherId: string, to: string, tokenIds: any, amounts:any, data:any) {
    const domain = {
      name: 'Lazymint-ReloadedNFT',
      version: '1',
      verifyingContract: lazyMint.address,
      chainId: 31337
    }

    const types2 = {
      EIP712Domain: [
        { name: 'name', type: 'string' },
        { name: 'version', type: 'string' },
        { name: 'chainId', type: 'uint256' },
        { name: 'verifyingContract', type: 'address' }
      ],
      MintBatchVoucher: [
        { name: 'voucherId', type: 'bytes16' },
        { name: 'to', type: 'address' },
        { name: 'tokenIds', type: 'uint256[]' },
        { name: 'amounts', type: 'uint256[]' },
        { name: 'data', type: 'bytes' }
      ]
    }

    const privateKey = Buffer.from(
      this.privateKey.slice(2),
      'hex'
    )

    const signature2 = signTypedData({
      privateKey: privateKey,
      data: {
        types: types2,
        primaryType: 'MintBatchVoucher',
        domain: domain,
        message: {
          voucherId: 0,
          to,
          tokenIds,
          amounts,
          data
        }
      },
      version: SignTypedDataVersion.V4
    })

    return {
      signature: signature2,
      voucherId: voucherId,
      to: to,
      tokenIds,
      amounts,
      data
    }
  }
}

describe('Lazy mint nft', function () {
  let nft: Contract
  let admin: any
  let player1: SignerWithAddress

  before('deploying', async () => {
    const signers = await ethers.getSigners()
    admin = signers[0]
    player1 = signers[1]
  })

  it('Deploy NFT contract', async function () {
    const NFT = await ethers.getContractFactory('ReloadedNFT')
    nft = await NFT.deploy()
    await nft.deployed()
  })

  it('Deploy lazyMint', async function () {
    const LazyMint = await ethers.getContractFactory('LazyReloadedNFTMinter')
    lazyMint = await LazyMint.connect(admin).deploy(nft.address, admin.address)
    await lazyMint.deployed()
  })

  it('can mint NFT', async function () {
    // give minter role to the lazymint contract
    const minterRole = await nft.MINTER_ROLE()
    await nft.connect(admin).grantRole(minterRole, lazyMint.address)
    // create voucher
    const lazyminter = new LazyMinter({
      contract: lazyMint.address,
      privateKey: '0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80'
    })
    const voucher1 = await lazyminter.createVoucher(
      '0x30B4C5DA908E1B4DBFAB8E3C50BEB55B',
      '0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266',
      [0, 1],
      [1, 2],
      '0x00'
    )
    await lazyMint.connect(player1).lazyMint({
      signature: voucher1.signature,
      signer: '0x0000000000000000000000000000000000000000',
      message: {
        voucherId: voucher1.voucherId,
        to: voucher1.to,
        tokenIds: voucher1.tokenIds,
        amounts: voucher1.amounts,
        data: voucher1.data
      }
    })
    const amount = await nft.balanceOfBatch([admin.address, admin.address], [0, 1])

    expect(
      amount[0].toString()
    ).to.equal('1')

    expect(
      amount[1].toString()
    ).to.equal('2')
  })
})
