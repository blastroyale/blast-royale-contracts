
module.exports = async function ({ deployments, getNamedAccounts }: any) {
  const { deploy } = deployments
  const { deployer } = await getNamedAccounts()

  await deploy('LazyReloadedNFTMinter', {
    from: deployer,
    args: ['0x377F70FF5Aaa97537256476C974dce06dB3b00D1', '0x7Ac410F4E36873022b57821D7a8EB3D7513C045a'],
    log: true,
    waitConfirmations: 1
  })
}

module.exports.tags = ['LazyCSMinter']
