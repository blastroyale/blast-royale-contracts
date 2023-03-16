import hre, { ethers } from 'hardhat'
import BlastLootBoxABI from '../artifacts/contracts/BlastLootBox.sol/BlastLootBox.json'

async function main () {
  const { get } = hre.deployments
  const [signer] = await ethers.getSigners()
  const BlastLootBox = await get('BlastLootBox')

  const blastLootbox = new ethers.Contract(
    BlastLootBox.address,
    BlastLootBoxABI.abi,
    signer
  )

  const tx = await (await blastLootbox.setOpenAvailableStatus(true)).wait()
  console.log('✅ [BlastLootbox] setOpenAvailable status updated')
  console.log(` tx: ${tx.transactionHash}`)
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error)
  process.exitCode = 1
})
