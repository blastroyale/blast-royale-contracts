/* eslint-disable node/no-missing-import */
import { ethers } from "hardhat";
import { BigNumber } from "ethers";
import { writeAddress } from "./helper";

async function main() {
  const [deployer] = await ethers.getSigners();

  console.log("Deploying contracts with the account:", deployer.address);
  console.log("Account balance:", (await deployer.getBalance()).toString());

  // BLT
  const PrimaryToken = await ethers.getContractFactory("PrimaryToken");
  const primaryToken = await PrimaryToken.deploy(
    "Blast Token",
    "BLT",
    "0x59B5591494653Eafd3dA02B0f1Bc25D828A4191D",
    ethers.utils.parseEther("512000000") // fixed supply 512M
  );
  console.log("Primary token address:", primaryToken.address);

  // CS
  const SecondaryToken = await ethers.getContractFactory("SecondaryToken");
  const secondaryToken = await SecondaryToken.deploy(
    "Craft Spice",
    "CS",
    BigNumber.from("10000000000000000000000")
  );
  await secondaryToken.deployed();
  console.log("Secondary token address:", secondaryToken.address);

  writeAddress({
    deployerAddress: deployer.address,
    PrimaryToken: primaryToken.address,
    // SecondaryToken: secondaryToken.address,
  });
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
