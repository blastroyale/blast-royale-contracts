/* eslint-disable node/no-missing-import */
import { ethers } from "hardhat";
import fs from "fs";
import path from "path";
import { writeAddress } from "./helper";

async function main() {
  const [deployer] = await ethers.getSigners();

  console.log("Deploying contracts with the account:", deployer.address);
  console.log("Account balance:", (await deployer.getBalance()).toString());

  const addresses = JSON.parse(
    fs.readFileSync(path.resolve(__dirname, "../address.json"), {
      encoding: "utf8",
      flag: "r",
    })
  );
  const primaryTokenAddress = addresses.PrimaryToken;

  if (!primaryTokenAddress)
    return console.error(
      "Primary Token should be deployed before deploying vesting contract"
    );

  // Token vesting
  const TokenVesting = await ethers.getContractFactory("TokenVesting");
  const vesting = await TokenVesting.deploy(primaryTokenAddress);
  await vesting.deployed();
  console.log("TokenVesting address address:", vesting.address);

  writeAddress({
    Vesting: vesting.address,
  });
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
