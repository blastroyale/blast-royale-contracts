
module.exports = async function ({ deployments, getNamedAccounts }: any) {
  const { deploy, get } = deployments
  const { deployer } = await getNamedAccounts()

  const PrimaryTokenAddress = (await get('PrimaryToken')).address

  await deploy('TokenVesting', {
    from: deployer,
    args: [PrimaryTokenAddress],
    log: true,
    waitConfirmations: 1
  })
}

module.exports.tags = ['TokenVesting']
