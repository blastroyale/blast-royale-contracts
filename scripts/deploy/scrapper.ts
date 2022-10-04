/* eslint-disable node/no-missing-import */
import hre, { ethers } from "hardhat";
import { getAddress, writeAddress } from "./helper";

async function main() {
  const [deployer] = await ethers.getSigners();

  console.log("Deploying contracts with the account:", deployer.address);
  console.log("Account balance:", (await deployer.getBalance()).toString());

  // Validation processing
  const addresses = getAddress(hre.network.name);
  if (!addresses.BlastEquipmentNFT)
    return console.error("No BlastEquipment NFT address");
  if (!addresses.SecondaryToken)
    return console.error("No Secondary Token address");

  // Scrapper
  const Scrapper = await ethers.getContractFactory("Scrapper");
  const scrapperInstance = await Scrapper.deploy(
    addresses.BlastEquipmentNFT,
    addresses.SecondaryToken
  );
  await scrapperInstance.deployed();
  console.log("Scrapper address:", scrapperInstance.address);

  writeAddress(hre.network.name, {
    Scrapper: scrapperInstance.address,
  });
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
