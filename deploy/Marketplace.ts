module.exports = async function ({ deployments, getNamedAccounts }: any) {
  const { deploy, get } = deployments
  const { deployer } = await getNamedAccounts()

  const EquipmentAddress = (await get('BlastEquipmentNFT')).address

  await deploy('Marketplace', {
    from: deployer,
    args: [EquipmentAddress],
    log: true,
    waitConfirmations: 1
  })
}

module.exports.tags = ['Marketplace']
