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
  const blst = await BLST.connect(deployer).deploy('Blast Equipment', '$BLST')
  await blst.deployed()
  return blst
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

export const mintBLST = async (
  deployer: Signer,
  blst: any,
  target: Signer,
  amount: number
) => {
  const fakeURIs = new Array(amount).fill('ipfs://').map((x, i) => x + i)
  const fakeHashes = new Array(amount)
    .fill('0x000')
    .map((x, i) => ethers.utils.formatBytes32String(x + i))
  const realURIs = new Array(amount).fill('ipfs://real_').map((x, i) => x + i)
  const staticAttributes = new Array(amount).fill([5, 0, 0, 0, 0])
  const tx = await blst
    .connect(deployer)
    .safeMint(
      await target.getAddress(),
      fakeURIs,
      fakeHashes,
      realURIs,
      staticAttributes
    )
  await tx.wait()
}

export const getTimestampByBlockNumber = async (
  blockNumber: number
): Promise<number> => {
  const blockBefore = await ethers.provider.getBlock(blockNumber)
  return blockBefore.timestamp
}
