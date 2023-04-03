module.exports = async function ({ deployments, getNamedAccounts }: any) {
  const { deploy, get } = deployments
  const { deployer } = await getNamedAccounts()

  const BlastboxAddress = '0x9f6fBb9736F1cEc0376215F1d2a99fA8670dEC0F'
  await deploy('BlastBoxMarketplace', {
    from: deployer,
    args: [BlastboxAddress],
    log: true,
    waitConfirmations: 1
  })
}

module.exports.tags = ['BlastBoxMarketplace']
