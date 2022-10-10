import { ethers } from 'hardhat'
import { getMerkleRoots } from '../utils/helper'

module.exports = async function ({ deployments, getNamedAccounts }: any) {
  const { deploy, get } = deployments
  const { deployer } = await getNamedAccounts()

  // const { merkleRoot, luckyMerkleRoot }: any = await getMerkleRoots()
  const BlastLootboxAddress = (await get('BlastLootBox')).address

  await deploy('MarketplaceLootbox', {
    from: deployer,
    args: [BlastLootboxAddress, ethers.utils.formatBytes32String('0x0'), ethers.utils.formatBytes32String('0x0')],
    log: true,
    waitConfirmations: 1
  })
}

module.exports.tags = ['MarketplaceLootbox']
