import { BigNumber } from "ethers";
import hre from "hardhat";
import fs from "fs";

async function main() {
  const _address = fs.readFileSync("./scripts/address.json", {
    encoding: "utf8",
    flag: "r",
  });
  const addresses = JSON.parse(_address);

  // Verify BlastNFT Contract
  await hre.run("verify:verify", {
    address: addresses.blastNFT,
    constructorArguments: ["Blast Royale NFT", "BRW"],
    contract: "contracts/BlastNFT.sol:BlastNFT",
  });

  // Verify Primary Token Contract
  await hre.run("verify:verify", {
    address: addresses.primaryToken,
    constructorArguments: [
      "Blast Token",
      "BLT",
      addresses.deployerAddress,
      BigNumber.from("10000000000000000000000"),
    ],
    contract: "contracts/PrimaryToken.sol:PrimaryToken",
  });

  // Verify Marketplace Contract
  await hre.run("verify:verify", {
    address: addresses.marketplaceAddress,
    constructorArguments: [addresses.blastNFT, addresses.primaryToken],
    contract: "contracts/Marketplace.sol:Marketplace",
  });

  // Verify Secondary Token Contract
  await hre.run("verify:verify", {
    address: addresses.secondaryToken,
    constructorArguments: [
      "Craft Spice",
      "CS",
      addresses.deployerAddress,
      BigNumber.from("10000000000000000000000"),
    ],
    contract: "contracts/SecondaryToken.sol:SecondaryToken",
  });
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
