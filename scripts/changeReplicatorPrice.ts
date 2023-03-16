import hre, { ethers } from 'hardhat'
import ReplicatorABI from '../artifacts/contracts/Utilities/Replicator.sol/Replicator.json'

async function main () {
  const { get } = hre.deployments
  const [signer] = await ethers.getSigners()
  const replicatorAddress = await get('Replicator')

  const replicator = new ethers.Contract(
    replicatorAddress.address,
    ReplicatorABI.abi,
    signer
  )
  await replicator.setBLTPrices([
    ethers.BigNumber.from('7000000000000000000'),
    ethers.BigNumber.from('9000000000000000000'),
    ethers.BigNumber.from('12000000000000000000'),
    ethers.BigNumber.from('15000000000000000000'),
    ethers.BigNumber.from('20000000000000000000'),
    ethers.BigNumber.from('25000000000000000000'),
    ethers.BigNumber.from('30000000000000000000')
  ])
  await replicator.setCSPrices([
    ethers.BigNumber.from('250000000000000000000'),
    ethers.BigNumber.from('360000000000000000000'),
    ethers.BigNumber.from('640000000000000000000'),
    ethers.BigNumber.from('1000000000000000000000'),
    ethers.BigNumber.from('1800000000000000000000'),
    ethers.BigNumber.from('2800000000000000000000'),
    ethers.BigNumber.from('4500000000000000000000')
  ])
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error)
  process.exitCode = 1
})
