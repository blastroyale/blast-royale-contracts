import { getMerkleRoots } from '../utils/helper'

module.exports = async function ({ deployments, getNamedAccounts }: any) {
  const { deploy, get } = deployments
  const { deployer } = await getNamedAccounts()

  const { merkleRoot, luckyMerkleRoot }: any = await getMerkleRoots()
  const BlastLootboxAddress = (await get('BlastLootbox')).address

  await deploy('MarketplaceLootbox', {
    from: deployer,
    args: [merkleRoot, luckyMerkleRoot, BlastLootboxAddress],
    log: true,
    waitConfirmations: 1
  })
}

module.exports.tags = ['MarketplaceLootbox']
