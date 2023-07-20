
module.exports = async function ({ deployments, getNamedAccounts }: any) {
  const { deploy } = deployments
  const { deployer } = await getNamedAccounts()

  await deploy('ReloadedNFT', {
    from: deployer,
    log: true,
    waitConfirmations: 1
  })
}

module.exports.tags = ['ReloadedNFT']
