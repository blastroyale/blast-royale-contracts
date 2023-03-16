import { expect } from 'chai'
import { ethers } from 'hardhat'
import { deployBLST, deployLootbox, deployPrimary, deploySecondary, mintBLST } from './helper'

// const uri = "https://blastroyale.com/nft/";

describe('Blast LootBox Contract', function () {
  let owner: any
  let treasury: any
  let addr1: any
  let addr2: any
  let blst: any
  let blb: any
  let primary: any
  let secondary: any

  before('deploying', async () => {
    [owner, treasury, addr1, addr2] = await ethers.getSigners()
    primary = await deployPrimary(owner, owner, treasury)
    secondary = await deploySecondary(owner)
    blst = await deployBLST(owner)
    blb = await deployLootbox(owner, blst.address)
    await secondary
      .connect(owner)
      .claim(addr1.address, ethers.utils.parseEther('10000'))

    await primary
      .connect(treasury)
      .transfer(addr1.address, ethers.utils.parseEther('10000000'))

    await mintBLST(owner, blst, blb.address, 3)

    // Grant REVEAL_ROLE to Lootbox contract
    const REVEAL_ROLE = await blst.REVEAL_ROLE()
    await blst.connect(owner).grantRole(REVEAL_ROLE, blb.address)

    // Lootbox Minting to address with Equipment NFT ids [0, 1, 2]
    const tx = await blb.connect(owner).safeMint(
      [owner.address],
      ['ipfs://111'],
      [
        {
          token0: ethers.BigNumber.from('0'),
          token1: ethers.BigNumber.from('1'),
          token2: ethers.BigNumber.from('2')
        }
      ],
      1
    )
    await tx.wait()
  })

  it('Open function test', async function () {
    // Lootbox contract has 3 Equipment NFT items
    expect(await blst.balanceOf(blb.address)).to.equal(3)
    // Owner don't have Equipment NFT
    expect(await blst.balanceOf(owner.address)).to.equal(0)
    // Owner only have 1 Lootbox NFT
    expect(await blb.balanceOf(owner.address)).to.equal(1)

    // Owner opens the Lootbox
    await blb.setOpenAvailableStatus(true)
    const openTx = await blb.connect(owner).open(0)
    await openTx.wait()

    // Now, 3 Equipment items which Lootbox contract had transferred to Owner
    expect(await blst.balanceOf(blb.address)).to.equal(0)
    // Owner balance of Equipment NFT is 3
    expect(await blst.balanceOf(owner.address)).to.equal(3)
    // Owner has no Lootbox NFT because it's already burnt
    expect(await blb.balanceOf(owner.address)).to.equal(0)

    // Reveal test

    expect(await blst.tokenURI(0)).to.equal('https://static.blastroyale.com/ipfs://real_0')
    expect(await blst.tokenURI(1)).to.equal('https://static.blastroyale.com/ipfs://real_1')
    expect(await blst.tokenURI(2)).to.equal('https://static.blastroyale.com/ipfs://real_2')
  })

  it('Open multiple lootbox items', async () => {
    // Equipment NFT minting process
    const mintTx1 = await blst.connect(owner).safeMint(
      blb.address,
      [
        ethers.utils.keccak256('0x1000'),
        ethers.utils.keccak256('0x2000'),
        ethers.utils.keccak256('0x3000'),
        ethers.utils.keccak256('0x4000'),
        ethers.utils.keccak256('0x5000'),
        ethers.utils.keccak256('0x6000')
      ],
      [
        'ipfs://111_real',
        'ipfs://222_real',
        'ipfs://333_real',
        'ipfs://444_real',
        'ipfs://555_real',
        'ipfs://666_real'
      ],
      [
        [5, 0, 3, 0, 0, 0],
        [5, 0, 3, 0, 0, 0],
        [5, 0, 3, 0, 0, 0],
        [5, 0, 3, 0, 0, 0],
        [5, 0, 3, 0, 0, 0],
        [5, 0, 3, 0, 0, 0]
      ]
    )
    await mintTx1.wait()

    const tx = await blb.connect(owner).safeMint(
      [addr1.address, addr1.address],
      ['ipfs://111', 'ipfs://222'],
      [
        {
          token0: ethers.BigNumber.from('3'),
          token1: ethers.BigNumber.from('4'),
          token2: ethers.BigNumber.from('5')
        },
        {
          token0: ethers.BigNumber.from('6'),
          token1: ethers.BigNumber.from('7'),
          token2: ethers.BigNumber.from('8')
        }
      ],
      1
    )
    await tx.wait()

    expect(await blb.balanceOf(addr1.address)).to.eq(2)

    const openTx = await blb.connect(owner).openTo(1, addr1.address)
    await openTx.wait()
  })

  it('Can create an empty lootbox with no Blast Equipment minted', async () => {
    // creating a lootbox with tokens that do not exist
    const tx = await blb.connect(owner).safeMint(
      [addr2.address],
      ['ipfs://999'],
      [
        {
          token0: ethers.BigNumber.from('123'),
          token1: ethers.BigNumber.from('789'),
          token2: ethers.BigNumber.from('999')
        }
      ],
      1
    )
    await tx.wait()

    expect(await blb.balanceOf(addr2.address)).to.eq(1)

    expect(blb.connect(owner).openTo(3, addr2.address)).to.be.revertedWith(
      'ERC721: operator query for nonexistent token'
    )
    // player should not receive any equipment NFT
    expect(await blst.balanceOf(addr2.address)).to.equal(0)
  })
})
