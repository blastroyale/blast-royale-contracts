import hre from 'hardhat'
import NFTArgs from '../constants/NFTArgs.json'

const NFT_ARGS: any = NFTArgs

module.exports = async function ({ deployments, getNamedAccounts }: any) {
  const { deploy, get } = deployments
  const { deployer } = await getNamedAccounts()

  const lootboxArgs = NFT_ARGS.Lootbox[hre.network.name]

  const EquipmentAddress = (await get('BlastEquipmentNFT')).address

  await deploy('BlastLootBox', {
    from: deployer,
    args: [
      lootboxArgs.name,
      lootboxArgs.symbol,
      EquipmentAddress
    ],
    log: true,
    waitConfirmations: 1
  })
}

module.exports.tags = ['BlastLootBox']
