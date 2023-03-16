
module.exports = async function ({ deployments, getNamedAccounts }: any) {
  const { deploy, get } = deployments
  const { deployer } = await getNamedAccounts()

  const BlastEquipmentNFTAddress = (await get('BlastEquipmentNFT')).address
  const SecondaryTokenAddress = (await get('SecondaryToken')).address

  await deploy('Scrapper', {
    from: deployer,
    args: [
      BlastEquipmentNFTAddress,
      SecondaryTokenAddress
    ],
    log: true,
    waitConfirmations: 1
  })
}

module.exports.tags = ['Scrapper']
