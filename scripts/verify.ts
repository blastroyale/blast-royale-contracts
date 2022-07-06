/* eslint-disable node/no-missing-import */
import hre from "hardhat";
import { BigNumber } from "ethers";
import NFTArgs from "../constants/NFTArgs.json";
import TokenArgs from "../constants/TokenArgs.json";
import ReplicatorArgs from "../constants/ReplicatorArgs.json";
import { getAddress } from "./deploy/helper";

const NFT_ARGS: any = NFTArgs;
const TOKEN_ARGS: any = TokenArgs;
const REPLICATOR_ARGS: any = ReplicatorArgs;

async function main() {
  const addresses = getAddress(hre.network.name);

  // Verify BlastEquipmentNFT Contract
  try {
    await hre.run("verify:verify", {
      address: addresses.BlastEquipmentNFT,
      constructorArguments: [
        NFT_ARGS.Equipment[hre.network.name].name,
        NFT_ARGS.Equipment[hre.network.name].symbol,
      ],
      contract: "contracts/BlastEquipmentNFT.sol:BlastEquipmentNFT",
    });
  } catch (err) {
    console.error(err);
  }

  // Verify BlastLootBox Contract
  try {
    await hre.run("verify:verify", {
      address: addresses.BlastLootBox,
      constructorArguments: [
        NFT_ARGS.Lootbox[hre.network.name].name,
        NFT_ARGS.Lootbox[hre.network.name].symbol,
        addresses.BlastEquipmentNFT,
      ],
      contract: "contracts/BlastLootBox.sol:BlastLootBox",
    });
  } catch (err) {
    console.error(err);
  }

  // Verify Replicator Contract
  try {
    await hre.run("verify:verify", {
      address: addresses.Replicator,
      constructorArguments: [
        addresses.BlastEquipmentNFT,
        addresses.PrimaryToken,
        addresses.SecondaryToken,
        REPLICATOR_ARGS.Replicator[hre.network.name].treasuryAddress,
        REPLICATOR_ARGS.Replicator[hre.network.name].companyAddress,
      ],
      contract: "contracts/Replicator.sol:Replicator",
    });
  } catch (err) {
    console.error(err);
  }

  // Verify Marketplace Contract
  try {
    await hre.run("verify:verify", {
      address: addresses.LootboxMarketplace,
      constructorArguments: [
        addresses.BlastLootBox,
        "0xd68c0a864e79ef65d97ede9d587355983dca17089d7fe63699717f7aceeeba85",
        "0x2fbe3b63c32b738129d3a1578400d64555da3e2dd2945119256b149e14de2db9",
      ],
      contract: "contracts/MarketplaceLootbox.sol:MarketplaceLootbox",
    });
  } catch (err) {
    console.error(err);
  }

  // Verify Marketplace Contract
  try {
    await hre.run("verify:verify", {
      address: addresses.Marketplace,
      constructorArguments: [addresses.BlastEquipmentNFT],
      contract: "contracts/Marketplace.sol:Marketplace",
    });
  } catch (err) {
    console.error(err);
  }

  // Verify Primary Token Contract
  try {
    await hre.run("verify:verify", {
      address: addresses.PrimaryToken,
      constructorArguments: [
        TOKEN_ARGS.PrimaryToken[hre.network.name].name,
        TOKEN_ARGS.PrimaryToken[hre.network.name].symbol,
        addresses.deployerAddress,
        BigNumber.from("10000000000000000000000"),
      ],
      contract: "contracts/PrimaryToken.sol:PrimaryToken",
    });
  } catch (err) {
    console.error(err);
  }

  // Verify Secondary Token Contract
  try {
    await hre.run("verify:verify", {
      address: addresses.secondaryToken,
      constructorArguments: [
        TOKEN_ARGS.SecondaryToken[hre.network.name].name,
        TOKEN_ARGS.SecondaryToken[hre.network.name].symbol,
        BigNumber.from("10000000000000000000000"),
      ],
      contract: "contracts/SecondaryToken.sol:SecondaryToken",
    });
  } catch (err) {
    console.error(err);
  }
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
