/* eslint-disable node/no-missing-import */
import hre, { ethers } from "hardhat";
import { getAddress, writeAddress } from "./helper";
import Args from "../../constants/ReplicatorArgs.json";

const replicatorArgs: any = Args;

async function main() {
  const [deployer] = await ethers.getSigners();

  console.log("Deploying contracts with the account:", deployer.address);
  console.log("Account balance:", (await deployer.getBalance()).toString());

  // Validation processing
  const addresses = getAddress(hre.network.name);
  if (!addresses.BlastEquipmentNFT)
    return console.error("No BlastEquipment NFT address");
  if (!addresses.PrimaryToken) return console.error("No Primary Token address");
  if (!addresses.SecondaryToken)
    return console.error("No Secondary Token address");

  // Repairing
  const Repairing = await ethers.getContractFactory("Repairing");
  const repairingInstance = await Repairing.deploy(
    addresses.BlastEquipmentNFT,
    addresses.PrimaryToken,
    addresses.SecondaryToken,
    replicatorArgs.Replicator[hre.network.name].treasuryAddress,
    replicatorArgs.Replicator[hre.network.name].companyAddress
  );
  await repairingInstance.deployed();
  console.log("Repairing address:", repairingInstance.address);

  writeAddress(hre.network.name, {
    deployerAddress: deployer.address,
    Repairing: repairingInstance.address,
  });
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
