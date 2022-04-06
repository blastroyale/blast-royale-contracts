import hre from "hardhat";
import fs from "fs";

async function main() {
  const _address = fs.readFileSync("./scripts/address.json", {
    encoding: "utf8",
    flag: "r",
  });
  const addresses = JSON.parse(_address);

  // Verify BlastEquipmentNFT Contract
  await hre.run("verify:verify", {
    address: addresses.BlastEquipmentNFT,
    constructorArguments: ["Blast Equipment NFT", "BEN"],
    contract: "contracts/BlastEquipmentNFT.sol:BlastEquipmentNFT",
  });

  // // Verify Primary Token Contract
  // await hre.run("verify:verify", {
  //   address: addresses.primaryToken,
  //   constructorArguments: [
  //     "Blast Token",
  //     "BLT",
  //     addresses.deployerAddress,
  //     BigNumber.from("10000000000000000000000"),
  //   ],
  //   contract: "contracts/PrimaryToken.sol:PrimaryToken",
  // });

  // Verify BlastLootBox Contract
  await hre.run("verify:verify", {
    address: addresses.BlastLootBox,
    constructorArguments: ["Blast Token", "BLT"],
    contract: "contracts/BlastLootBox.sol:BlastLootBox",
  });

  // // Verify Secondary Token Contract
  // await hre.run("verify:verify", {
  //   address: addresses.secondaryToken,
  //   constructorArguments: [
  //     "Craft Spice",
  //     "CS",
  //     addresses.deployerAddress,
  //     BigNumber.from("10000000000000000000000"),
  //   ],
  //   contract: "contracts/SecondaryToken.sol:SecondaryToken",
  // });
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
