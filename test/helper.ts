import { Signer } from 'ethers'
import { ethers } from 'hardhat'

export const deployPrimary = async (
  deployer: Signer,
  owner: Signer,
  treasury: Signer
) => {
  const BLST = await ethers.getContractFactory('PrimaryToken')
  const blst = await BLST.connect(deployer).deploy(
    'Blast Royale',
    '$BLT',
    await owner.getAddress(),
    await treasury.getAddress(),
    ethers.utils.parseEther('512000000')
  )
  await blst.deployed()
  return blst
}

export const deploySecondary = async (deployer: Signer) => {
  const CraftToken = await ethers.getContractFactory('SecondaryToken')
  const cs = await CraftToken.connect(deployer).deploy(
    'Craftship',
    '$CS',
    ethers.utils.parseEther('100000000'),
    await deployer.getAddress()
  )
  await cs.deployed()
  return cs
}

export const deployBLST = async (deployer: Signer) => {
  const BLST = await ethers.getContractFactory('BlastEquipmentNFT')
  const blst = await BLST.connect(deployer).deploy(
    'Blast Equipment', '$BLST',
    'https://static.blastroyale.com/previewMetadata.json',
    'https://static.blastroyale.com/'
  )
  await blst.deployed()
  return blst
}

export const deployLootbox = async (deployer: Signer, blstAddress: string) => {
  const BLB = await ethers.getContractFactory('BlastLootBox')
  const blb = await BLB.connect(deployer).deploy(
    'Blast LootBox',
    'BLB',
    blstAddress
  )
  await blb.deployed()
  return blb
}

export const deployMarketplace = async (deployer: Signer, blstAddress: string) => {
  const BLB = await ethers.getContractFactory('Marketplace')
  const blb = await BLB.connect(deployer).deploy(blstAddress)
  await blb.deployed()
  return blb
}

export const deployReplicator = async (
  deployer: Signer,
  blst: string,
  primary: string,
  secondary: string,
  treasury: string,
  company: string
) => {
  const replicator = await ethers.getContractFactory('Replicator')
  const replicatorContract = await replicator
    .connect(deployer)
    .deploy(blst, primary, secondary, treasury, company)
  await replicatorContract.deployed()
  return replicatorContract
}

export const deployUpgrader = async (
  deployer: Signer,
  blst: string,
  primary: string,
  secondary: string,
  treasury: string,
  company: string
) => {
  const upgraderFactory = await ethers.getContractFactory('Upgrader')
  const upgrader = await upgraderFactory
    .connect(deployer)
    .deploy(blst, primary, secondary, treasury, company)
  await upgrader.deployed()
  return upgrader
}

export const deployRepairing = async (
  deployer: Signer,
  blst: string,
  primary: string,
  secondary: string,
  treasury: string,
  company: string
) => {
  const repairingFactory = await ethers.getContractFactory('Repairing')
  const repairing = await repairingFactory
    .connect(deployer)
    .deploy(blst, primary, secondary, treasury, company)
  await repairing.deployed()

  return repairing
}

export const deployScrapper = async (
  deployer: Signer,
  blst: string,
  secondary: string
) => {
  const scrapperFactory = await ethers.getContractFactory('Scrapper')
  const scrapper = await scrapperFactory
    .connect(deployer)
    .deploy(blst, secondary)
  await scrapper.deployed()
  return scrapper
}

export const mintBLST = async (
  deployer: Signer,
  blst: any,
  target: Signer | string,
  amount: number
) => {
  const fakeHashes = new Array(amount)
    .fill('0x000')
    .map((x, i) => ethers.utils.formatBytes32String(x + i))
  const realURIs = new Array(amount).fill('ipfs://real_').map((x, i) => x + i)
  const staticAttributes = new Array(amount).fill([5, 114, 3, 9, 9, 5])
  const tx = await blst
    .connect(deployer)
    .safeMint(
      typeof target === 'string' ? target : await target.getAddress(),
      fakeHashes,
      realURIs,
      staticAttributes
    )
  await tx.wait()
}

export const configureMarketplace = async (
  marketplace: any,
  treasury1: string,
  treasury2: string,
  fee1: string,
  fee2: string
) => {
  await marketplace.setFee(fee1, treasury1, fee2, treasury2)
}

export const getTimestampByBlockNumber = async (
  blockNumber: number
): Promise<number> => {
  const blockBefore = await ethers.provider.getBlock(blockNumber)
  return blockBefore.timestamp
}
