
module.exports = async function ({ deployments, getNamedAccounts }: any) {
  const { deploy, get } = deployments
  const { deployer } = await getNamedAccounts()

  await deploy('Corpos', {
    from: deployer,
    args: [
      'Corpos',
      'CORPO',
      'https://dev-metadata.blastroyale.com/nftmetadata/',
      888,
      888,
      '0x7Ac410F4E36873022b57821D7a8EB3D7513C045a',
      3600000000000000
    ],
    log: true,
    waitConfirmations: 1
  })
}

module.exports.tags = ['Corpos']
