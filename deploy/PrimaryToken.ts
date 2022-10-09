
import { BigNumber } from 'ethers'
import hre from 'hardhat'
import TokenArgs from '../constants/TokenArgs.json'

const TOKEN_ARGS: any = TokenArgs

module.exports = async function ({ deployments, getNamedAccounts }: any) {
  const { deploy } = deployments
  const { deployer } = await getNamedAccounts()

  const primaryTokenArgs = TOKEN_ARGS.PrimaryToken[hre.network.name]

  await deploy('PrimaryToken', {
    from: deployer,
    args: [
      primaryTokenArgs.name,
      primaryTokenArgs.symbol,
      primaryTokenArgs.ownerAddress, // owner address
      primaryTokenArgs.treasuryAddress, // treasury address
      BigNumber.from(primaryTokenArgs.supply) // fixed supply 512M
    ],
    log: true,
    waitConfirmations: 1
  })
}

module.exports.tags = ['PrimaryToken']
