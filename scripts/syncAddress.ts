import hre from 'hardhat'
import { writeAddress } from '../utils/helper'

async function main () {
  const { get } = hre.deployments

  const BlastEquipmentNFTAddress = (await get('BlastEquipmentNFT')).address
  const BlastLootboxAddress = (await get('BlastLootBox')).address
  const MarketplaceAddress = (await get('Marketplace')).address
  const MarketplaceLootboxAddress = (await get('MarketplaceLootbox')).address
  const PrimaryTokenAddress = (await get('PrimaryToken')).address
  const SecondaryTokenAddress = (await get('SecondaryToken')).address
  const RepairingAddress = (await get('Repairing')).address
  const ReplicatorAddress = (await get('Replicator')).address
  const ScrapperAddress = (await get('Scrapper')).address
  const UpgraderAddress = (await get('Upgrader')).address
  const VestingAddress = (await get('TokenVesting')).address

  writeAddress(hre.network.name, {
    BlastEquipmentNFT: BlastEquipmentNFTAddress,
    BlastLootBox: BlastLootboxAddress,
    Marketplace: MarketplaceAddress,
    LootboxMarketplace: MarketplaceLootboxAddress,
    PrimaryToken: PrimaryTokenAddress,
    SecondaryToken: SecondaryTokenAddress,
    Vesting: VestingAddress,
    Replicator: ReplicatorAddress,
    Repairing: RepairingAddress,
    Scrapper: ScrapperAddress,
    Upgrader: UpgraderAddress
  })
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error)
  process.exitCode = 1
})
