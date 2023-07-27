
module.exports = async function ({ deployments, getNamedAccounts }: any) {
  const { deploy } = deployments
  const { deployer } = await getNamedAccounts()

  await deploy('LazyUnlock', {
    from: deployer,
    args: ['0x6a062edB6008D02699BfB354C6BB4eb4B52B77a4', '0x7Ac410F4E36873022b57821D7a8EB3D7513C045a'],
    log: true,
    waitConfirmations: 1
  })
}

module.exports.tags = ['LazyUnlock']
