
import hre from 'hardhat'
import Args from '../constants/ReplicatorArgs.json'

const replicatorArgs: any = Args

module.exports = async function ({ deployments, getNamedAccounts }: any) {
  const { deploy, get } = deployments
  const { deployer } = await getNamedAccounts()

  const BlastEquipmentNFTAddress = (await get('BlastEquipmentNFT')).address
  const PrimaryTokenAddress = (await get('PrimaryToken')).address
  const SecondaryTokenAddress = (await get('SecondaryToken')).address

  await deploy('Upgrader', {
    from: deployer,
    args: [
      BlastEquipmentNFTAddress,
      PrimaryTokenAddress,
      SecondaryTokenAddress,
      replicatorArgs.Replicator[hre.network.name].treasuryAddress,
      replicatorArgs.Replicator[hre.network.name].companyAddress
    ],
    log: true,
    waitConfirmations: 1
  })
}

module.exports.tags = ['Upgrader']
