import hre, { ethers } from 'hardhat'
import EquipmentNFTABI from '../artifacts/contracts/BlastEquipmentNFT.sol/BlastEquipmentNFT.json'
import SecondaryTokenABI from '../artifacts/contracts/SecondaryToken.sol/SecondaryToken.json'
import ReplicatorABI from '../artifacts/contracts/Utilities/Replicator.sol/Replicator.json'

async function main () {
  const { get } = hre.deployments
  const [deployer] = await ethers.getSigners()

  const BlastEquipmentNFTAddress = (await get('BlastEquipmentNFT')).address
  const SecondaryTokenAddress = (await get('SecondaryToken')).address
  const ScrapperAddress = (await get('Scrapper')).address
  const RepairingAddress = (await get('Repairing')).address
  const ReplicatorAddress = (await get('Replicator')).address
  const UpgraderAddress = (await get('Upgrader')).address
  const LootboxAddress = (await get('BlastLootBox')).address
  const BackendWalletAddress = ''

  const blst = new ethers.Contract(
    BlastEquipmentNFTAddress,
    EquipmentNFTABI.abi,
    deployer
  )
  const cs = new ethers.Contract(
    SecondaryTokenAddress,
    SecondaryTokenABI.abi,
    deployer
  )
  const replicator = new ethers.Contract(
    ReplicatorAddress,
    ReplicatorABI.abi,
    deployer
  )

  // Granting GAME_ROLE role to Utility contracts
  const GAME_ROLE = await blst.GAME_ROLE()
  await blst.grantRole(GAME_ROLE, ScrapperAddress)
  await blst.grantRole(GAME_ROLE, RepairingAddress)
  await blst.grantRole(GAME_ROLE, UpgraderAddress)

  const REPLICATOR_ROLE = await blst.REPLICATOR_ROLE()
  await blst.grantRole(REPLICATOR_ROLE, ReplicatorAddress)

  const ADMIN_ROLE = await replicator.DEFAULT_ADMIN_ROLE()
  await replicator.grantRole(ADMIN_ROLE, BackendWalletAddress)

  // Granting MINTER ROLE to scrapper contract
  const REVEAL_ROLE = await blst.REVEAL_ROLE()
  await blst.grantRole(REVEAL_ROLE, ReplicatorAddress)
  await blst.grantRole(REVEAL_ROLE, LootboxAddress)

  // Granting MINTER ROLE to scrapper contract
  const MINTER_ROLE = await cs.MINTER_ROLE()
  await cs.grantRole(MINTER_ROLE, ScrapperAddress)
  await cs.grantRole(MINTER_ROLE, BackendWalletAddress)
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error)
  process.exitCode = 1
})
