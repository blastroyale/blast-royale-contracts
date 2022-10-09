import shell from 'shelljs'
import * as dotenv from 'dotenv'
dotenv.config()

export const verifyAll = async function (taskArgs: any, hre: any) {
  const checkWireUpCommand = `npx hardhat --network ${hre.network.name} etherscan-verify --api-key ${process.env.POLYGON_API_KEY}`
  shell.exec(checkWireUpCommand).stdout.replace(/(\r\n|\n|\r|\s)/gm, '')
}
