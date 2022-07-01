/* eslint-disable node/no-missing-import */
import hre, { ethers } from "hardhat";
import NFTArgs from "../../constants/NFTArgs.json";
import { writeAddress, getMerkleRoots } from "./helper";

const NFT_ARGS: any = NFTArgs;

async function main() {
  const [deployer] = await ethers.getSigners();
  const { merkleRoot, luckyMerkleRoot }: any = await getMerkleRoots();

  console.log("Deploying contracts with the account:", deployer.address);
  console.log("Account balance:", (await deployer.getBalance()).toString());

  // BlastEquipmentNFT
  const equipmentArgs = NFT_ARGS.Equipment[hre.network.name];
  const BlastEquipmentNFT = await ethers.getContractFactory(
    "BlastEquipmentNFT"
  );
  const blastEqtNFT = await BlastEquipmentNFT.deploy(
    equipmentArgs.name,
    equipmentArgs.symbol
  );
  await blastEqtNFT.deployed();
  console.log("BlastEquipmentNFT address address:", blastEqtNFT.address);

  // BlastLootBox
  const lootboxArgs = NFT_ARGS.Lootbox[hre.network.name];
  const BlastLootBox = await ethers.getContractFactory("BlastLootBox");
  const blastLootBox = await BlastLootBox.deploy(
    lootboxArgs.name,
    lootboxArgs.symbol,
    blastEqtNFT.address
  );
  console.log("BlastLootBox address:", blastLootBox.address);

  // Grant REVEAL_ROLE to lootbox contract address
  const REVEAL_ROLE = await blastEqtNFT.REVEAL_ROLE();
  const grantTx = await blastEqtNFT.grantRole(
    REVEAL_ROLE,
    blastLootBox.address
  );
  await grantTx.wait();
  console.log("Granted REVEAL_ROLE to Lootbox contract");

  // MarketplaceLootbox Deploying
  const MarketplaceLootbox = await ethers.getContractFactory(
    "MarketplaceLootbox"
  );
  const lootboxMarket = await MarketplaceLootbox.deploy(
    blastLootBox.address,
    merkleRoot,
    luckyMerkleRoot
  );
  console.log("BlastLootbox Marketplace address: ", lootboxMarket.address);

  // // NFT MARKETPLACE
  // const Marketplace = await ethers.getContractFactory("Marketplace");
  // const marketplace = await Marketplace.deploy(blastEqtNFT.address);
  // await marketplace.deployed();

  // console.log("Marketplace address address:", marketplace.address);

  writeAddress(hre.network.name, {
    deployerAddress: deployer.address,
    BlastEquipmentNFT: blastEqtNFT.address,
    BlastLootBox: blastLootBox.address,
    // Marketplace: marketplace.address,
    LootboxMarketplace: lootboxMarket.address,
  });
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
