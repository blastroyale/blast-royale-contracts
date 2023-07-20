
module.exports = async function ({ deployments, getNamedAccounts }: any) {
  const { deploy } = deployments
  const { deployer } = await getNamedAccounts()

  await deploy('LockContract', {
    from: deployer,
    log: true,
    waitConfirmations: 1
  })
}

module.exports.tags = ['LockContract']
