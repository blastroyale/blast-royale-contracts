import hre from "hardhat";
import fs from "fs";
import { BigNumber } from "ethers";

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

  // Verify BlastLootBox Contract
  await hre.run("verify:verify", {
    address: addresses.BlastLootBox,
    constructorArguments: ["Blast Lootbox", "BLX", addresses.BlastEquipmentNFT],
    contract: "contracts/BlastLootBox.sol:BlastLootBox",
  });

  // Verify Marketplace Contract
  await hre.run("verify:verify", {
    address: addresses.LootboxMarketplace,
    constructorArguments: [
      addresses.BlastLootBox,
      "0x6306a340f9f3dca2f533a296dc25e3616c0ab74c9d70260810a7a8be3c618d84",
      "0x6306a340f9f3dca2f533a296dc25e3616c0ab74c9d70260810a7a8be3c618d84",
    ],
    contract: "contracts/MarketplaceLootbox.sol:MarketplaceLootbox",
  });

  // // Verify Marketplace Contract
  // await hre.run("verify:verify", {
  //   address: addresses.Marketplace,
  //   constructorArguments: [addresses.BlastEquipmentNFT],
  //   contract: "contracts/Marketplace.sol:Marketplace",
  // });

  // // Verify Primary Token Contract
  // await hre.run("verify:verify", {
  //   address: addresses.PrimaryToken,
  //   constructorArguments: [
  //     "Blast Token",
  //     "BLT",
  //     addresses.deployerAddress,
  //     BigNumber.from("10000000000000000000000"),
  //   ],
  //   contract: "contracts/PrimaryToken.sol:PrimaryToken",
  // });

  // // Verify Secondary Token Contract
  // await hre.run("verify:verify", {
  //   address: addresses.secondaryToken,
  //   constructorArguments: [
  //     "Craft Spice",
  //     "CS",
  //     BigNumber.from("10000000000000000000000"),
  //   ],
  //   contract: "contracts/SecondaryToken.sol:SecondaryToken",
  // });
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
