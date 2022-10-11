import shell from 'shelljs'

export const deployAll = async function (taskArgs: any, hre: any) {
  const contractNames = [
    'PrimaryToken',
    'SecondaryToken',
    'BlastEquipmentNFT',
    'BlastLootBox',
    'Marketplace',
    'MarketplaceLootbox',
    'Repairing',
    'Replicator',
    'Scrapper',
    'Upgrader',
    'TokenVesting'
  ]

  await Promise.all(
    contractNames.map(async (contract: string) => {
      const checkWireUpCommand = `npx hardhat deploy --tags ${contract} --network ${hre.network.name}`
      shell.exec(checkWireUpCommand).stdout.replace(/(\r\n|\n|\r|\s)/gm, '')
    })
  )
}
