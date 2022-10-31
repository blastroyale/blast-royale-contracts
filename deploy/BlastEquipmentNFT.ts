import hre from 'hardhat'
import NFTArgs from '../constants/NFTArgs.json'

const NFT_ARGS: any = NFTArgs

module.exports = async function ({ deployments, getNamedAccounts, loadDeployments }: any) {
  const { deploy } = deployments
  const { deployer } = await getNamedAccounts()

  const equipmentArgs = NFT_ARGS.Equipment[hre.network.name]

  await deploy('BlastEquipmentNFT', {
    from: deployer,
    args: [equipmentArgs.name, equipmentArgs.symbol, equipmentArgs.previewURI, equipmentArgs.baseURI],
    log: true,
    waitConfirmations: 1
  })
}

module.exports.tags = ['BlastEquipmentNFT']
