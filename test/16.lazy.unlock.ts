import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers'
import { expect } from 'chai'
import { Contract, Signer } from 'ethers'
import { ethers, config } from 'hardhat'

import {
  signTypedData,
  SignTypedDataVersion
} from '@metamask/eth-sig-util'

const wallet = ethers.Wallet.createRandom().connect(ethers.provider)

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

  async createVoucher (voucherId: string, tokenContract: string, withdrawer: string, amounts:any, tokenIds:any) {
    const domain = {
      name: 'Lazy-Unlock',
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
      UnlockVoucher: [
        { name: 'voucherId', type: 'bytes16' },
        { name: 'tokenContract', type: 'address' },
        { name: 'withdrawer', type: 'address' },
        { name: 'tokenIds', type: 'uint256[]' },
        { name: 'amounts', type: 'uint256[]' }
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
        primaryType: 'UnlockVoucher',
        domain: domain,
        message: {
          voucherId: voucherId,
          tokenContract: tokenContract,
          withdrawer: withdrawer,
          tokenIds,
          amounts
        }
      },
      version: SignTypedDataVersion.V4
    })

    return {
      signature: signature2,
      voucherId: voucherId,
      tokenContract: tokenContract,
      withdrawer: withdrawer,
      tokenIds,
      amounts
    }
  }
}

describe('Lazy unlock', function () {
  let nft: Contract
  let lockContract: Contract
  let admin: any
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

  it('Deploy NFT contract', async function () {
    const NFT = await ethers.getContractFactory('ReloadedNFT')
    nft = await NFT.deploy()
    await nft.deployed()
  })

  it('Deploys lock contract', async function () {
    const LockContract = await ethers.getContractFactory('LockContract')
    lockContract = await LockContract.connect(admin).deploy()
    await lockContract.deployed()
  })

  it('Deploy lazyMint', async function () {
    const LazyMint = await ethers.getContractFactory('LazyUnlock')
    lazyMint = await LazyMint.connect(admin).deploy(lockContract.address, admin.address)
    await lazyMint.deployed()
  })

  it('can lazy unlock', async function () {
    await nft.connect(admin).mintBatch(admin.address, [0, 1], [1, 2], '0x00')

    await lockContract.connect(admin).addWhitelistedContract(nft.address)

    await nft.connect(admin).setApprovalForAll(lockContract.address, true)

    await expect(
      lockContract
        .connect(admin)
        .lockERC1155(nft.address, [0, 1], [1, 2])
    )
      .to.emit(lockContract, 'ERC1155Locked')
      .withArgs(admin.address, nft.address, [0, 1], [1, 2])
    // give minter role to the lazymint contract
    const minterRole = await nft.MINTER_ROLE()
    await nft.connect(admin).grantRole(minterRole, lazyMint.address)

    // create voucher
    const lazyminter = new LazyMinter({
      contract: lazyMint.address,
      privateKey: '0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80'
    })
    // voucherId: number, tokenContract: string, withdrawer: string, amounts:any,tokenIds:any
    const voucher1 = await lazyminter.createVoucher(
      '0x30B4C5DA908E1B4DBFAB8E3C50BEB55B',
      nft.address,
      player1.address,
      [1, 2],
      [0, 1]
    )
    const withdrawRole = await lockContract.WITHDRAW_ROLE()
    await lockContract.connect(admin).grantRole(withdrawRole, lazyMint.address)
    await lazyMint.connect(player1).lazyMint({
      signature: voucher1.signature,
      signer: '0x0000000000000000000000000000000000000000',
      message: {
        voucherId: voucher1.voucherId,
        tokenContract: voucher1.tokenContract,
        withdrawer: voucher1.withdrawer,
        amounts: voucher1.amounts,
        tokenIds: voucher1.tokenIds
      }
    })
    // await lockContract.connect(admin).withdrawERC1155(voucher1.tokenContract,voucher1.withdrawer,voucher1.tokenIds,voucher1.amounts)
    // let amount = await nft.balanceOfBatch([player1.address,player1.address],[0,1]);

    // expect(
    //   amount[0].toString()
    // ).to.equal('1')

    // expect(
    //   amount[1].toString()
    // ).to.equal('2')
  })
})
