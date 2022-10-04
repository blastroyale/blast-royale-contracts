/* eslint-disable node/no-missing-import */
import hre, { ethers } from "hardhat";
import { BigNumber } from "ethers";
import { writeAddress } from "./helper";
import TokenArgs from "../../constants/TokenArgs.json";

const TOKEN_ARGS: any = TokenArgs;

async function main() {
  const [deployer] = await ethers.getSigners();

  console.log("Deploying contracts with the account:", deployer.address);
  console.log("Account balance:", (await deployer.getBalance()).toString());

  // // BLT
  // const primaryTokenArgs = TOKEN_ARGS.PrimaryToken[hre.network.name];
  // const PrimaryToken = await ethers.getContractFactory("PrimaryToken");
  // const primaryToken = await PrimaryToken.deploy(
  //   primaryTokenArgs.name,
  //   primaryTokenArgs.symbol,
  //   primaryTokenArgs.ownerAddress, // owner address
  //   primaryTokenArgs.treasuryAddress, // treasury address
  //   BigNumber.from(primaryTokenArgs.supply) // fixed supply 512M
  // );
  // console.log("Primary token address:", primaryToken.address);

  // CS
  const secondaryTokenArgs = TOKEN_ARGS.SecondaryToken[hre.network.name];
  const SecondaryToken = await ethers.getContractFactory("SecondaryToken");
  const secondaryToken = await SecondaryToken.deploy(
    secondaryTokenArgs.name,
    secondaryTokenArgs.symbol,
    BigNumber.from(secondaryTokenArgs.supply),
    "0x7Ac410F4E36873022b57821D7a8EB3D7513C045a"
  );
  await secondaryToken.deployed();
  console.log("Secondary token address:", secondaryToken.address);

  writeAddress(hre.network.name, {
    deployerAddress: deployer.address,
    // PrimaryToken: primaryToken.address,
    SecondaryToken: secondaryToken.address,
  });
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
