/* eslint-disable node/no-missing-import */
import { ethers } from "hardhat";
import { writeAddress, getMerkleRoots } from "./helper";

async function main() {
  const [deployer] = await ethers.getSigners();
  const {merkleRoot, luckyMerkleRoot}:any =await getMerkleRoots();

  console.log("Deploying contracts with the account:", deployer.address);
  console.log("Account balance:", (await deployer.getBalance()).toString());

  // BlastEquipmentNFT
  const BlastEquipmentNFT = await ethers.getContractFactory(
    "BlastEquipmentNFT"
  );
  const blastEqtNFT = await BlastEquipmentNFT.deploy(
    "Blast Equipment NFT",
    "BEN"
  );
  await blastEqtNFT.deployed();
  console.log("BlastEquipmentNFT address address:", blastEqtNFT.address);

  // BlastLootBox
  const BlastLootBox = await ethers.getContractFactory("BlastLootBox");
  const blastLootBox = await BlastLootBox.deploy(
    "Blast Lootbox",
    "BLX",
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

  writeAddress({
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
