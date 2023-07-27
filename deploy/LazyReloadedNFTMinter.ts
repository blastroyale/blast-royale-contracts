
module.exports = async function ({ deployments, getNamedAccounts }: any) {
  const { deploy } = deployments
  const { deployer } = await getNamedAccounts()

  await deploy('LazyReloadedNFTMinter', {
    from: deployer,
    args: ['0x3700A37F2785E0724939b4AE7EF54286158F0b29', '0x7Ac410F4E36873022b57821D7a8EB3D7513C045a'],
    log: true,
    waitConfirmations: 1
  })
}

module.exports.tags = ['LazyReloadedNFTMinter']
