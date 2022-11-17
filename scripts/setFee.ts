import hre, { ethers } from 'hardhat'
import MarketplaceABI from '../artifacts/contracts/Marketplace.sol/Marketplace.json'

async function main () {
  const { get } = hre.deployments
  const [signer] = await ethers.getSigners()
  const Marketplace = await get('Marketplace')

  const marketplace = new ethers.Contract(
    Marketplace.address,
    MarketplaceABI.abi,
    signer
  )

  const tx = await (await marketplace.setFee(88, '0x602B24eB33c3Ce10C9b3C67D2a6B0D51329f4f34', 162, '0x7404B18a5c49E25051a1F498E4aBD9362E6Ca94a')).wait()
  console.log('✅ [Marketplace] fee & receiptant is updated')
  console.log(` tx: ${tx.transactionHash}`)
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error)
  process.exitCode = 1
})
