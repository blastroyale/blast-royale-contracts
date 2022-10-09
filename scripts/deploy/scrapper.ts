/* eslint-disable node/no-missing-import */
import hre, { ethers } from 'hardhat'
import { getAddress, writeAddress } from './helper'
import EquipmentNFTABI from '../../artifacts/contracts/BlastEquipmentNFT.sol/BlastEquipmentNFT.json'
import SecondaryTokenABI from '../../artifacts/contracts/SecondaryToken.sol/SecondaryToken.json'

async function main () {
  const [deployer] = await ethers.getSigners()

  console.log('Deploying contracts with the account:', deployer.address)
  console.log('Account balance:', (await deployer.getBalance()).toString())

  // Validation processing
  const addresses = getAddress(hre.network.name)
  if (!addresses.BlastEquipmentNFT) { return console.error('No BlastEquipment NFT address') }
  if (!addresses.SecondaryToken) { return console.error('No Secondary Token address') }

  // Scrapper
  const Scrapper = await ethers.getContractFactory('Scrapper')
  const scrapperInstance = await Scrapper.deploy(
    addresses.BlastEquipmentNFT,
    addresses.SecondaryToken
  )
  await scrapperInstance.deployed()
  console.log('Scrapper address:', scrapperInstance.address)

  writeAddress(hre.network.name, {
    Scrapper: scrapperInstance.address
  })

  const bet = new ethers.Contract(
    addresses.BlastEquipmentNFT,
    EquipmentNFTABI.abi,
    deployer
  )
  const cs = new ethers.Contract(
    addresses.SecondaryToken,
    SecondaryTokenABI.abi,
    deployer
  )
  // Granting GAME ROLE role to Upgrader contract address
  const GAME_ROLE = await bet.GAME_ROLE()
  await bet.grantRole(GAME_ROLE, scrapperInstance.address)

  // Granting MINTER ROLE to cs contract
  const MINTER_ROLE = await cs.MINTER_ROLE()
  await cs.grantRole(MINTER_ROLE, scrapperInstance.address)
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error)
  process.exitCode = 1
})
