module.exports = async function ({ deployments, getNamedAccounts }: any) {
  const { deploy, get } = deployments
  const { deployer } = await getNamedAccounts()

  const CSAddress = '0x0e10Af5940F50e8C0A85Ab29901c4867e3f7620C'

  await deploy('CSMarketplace', {
    from: deployer,
    args: [CSAddress],
    log: true,
    waitConfirmations: 1
  })
}

module.exports.tags = ['CSMarketplace']
