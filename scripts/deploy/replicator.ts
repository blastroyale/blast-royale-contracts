/* eslint-disable node/no-missing-import */
import { ethers } from "hardhat";
import { getAddress, writeAddress } from "./helper";

async function main() {
  const [deployer] = await ethers.getSigners();

  console.log("Deploying contracts with the account:", deployer.address);
  console.log("Account balance:", (await deployer.getBalance()).toString());

  // Validation processing
  const addresses = getAddress();
  if (!addresses.BlastEquipmentNFT)
    return console.error("No BlastEquipment NFT address");
  if (!addresses.PrimaryToken) return console.error("No Primary Token address");
  if (!addresses.SecondaryToken)
    return console.error("No Secondary Token address");

  // Replicator
  const Replicator = await ethers.getContractFactory("Replicator");
  const replicatorInstance = await Replicator.deploy(
    addresses.BlastEquipmentNFT,
    addresses.PrimaryToken,
    addresses.SecondaryToken
  );
  await replicatorInstance.deployed();
  console.log("BlastEquipmentNFT address address:", replicatorInstance.address);

  writeAddress({
    deployerAddress: deployer.address,
    Replicator: replicatorInstance.address,
  });
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
