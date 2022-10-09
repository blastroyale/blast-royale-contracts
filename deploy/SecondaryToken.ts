
import { BigNumber } from 'ethers'
import hre from 'hardhat'
import TokenArgs from '../constants/TokenArgs.json'

const TOKEN_ARGS: any = TokenArgs

module.exports = async function ({ deployments, getNamedAccounts }: any) {
  const { deploy } = deployments
  const { deployer } = await getNamedAccounts()

  const secondaryTokenArgs = TOKEN_ARGS.SecondaryToken[hre.network.name]

  await deploy('SecondaryToken', {
    from: deployer,
    args: [
      secondaryTokenArgs.name,
      secondaryTokenArgs.symbol,
      BigNumber.from(secondaryTokenArgs.supply),
      deployer.address
    ],
    log: true,
    waitConfirmations: 1
  })
}

module.exports.tags = ['SecondaryToken']
