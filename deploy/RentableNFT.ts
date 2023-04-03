
module.exports = async function ({ deployments, getNamedAccounts }: any) {
  const { deploy, get } = deployments
  const { deployer } = await getNamedAccounts()

  await deploy('RentableNFT', {
    from: deployer,
    args: [
      'Spice Corbos'],
    log: true,
    waitConfirmations: 1
  })
}

module.exports.tags = ['RentableNFT']
