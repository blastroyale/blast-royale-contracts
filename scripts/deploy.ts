import { ethers } from "hardhat";
import fs from "fs";
import { BigNumber } from "ethers";

async function main() {
  const [deployer] = await ethers.getSigners();

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

  // BLT
  console.log("Deploying primary token");
  const PrimaryToken = await ethers.getContractFactory("PrimaryToken");
  const primaryToken = await PrimaryToken.deploy(
    "Blast Token",
    "BLT",
    deployer.address,
    BigNumber.from("10000000000000000000000")
  );
  console.log("Primary token address:", primaryToken.address);

  // NFT MARKETPLACE
  const Marketplace = await ethers.getContractFactory("Marketplace");
  const marketplace = await Marketplace.deploy(
    blastEqtNFT.address,
    primaryToken.address
  );
  await marketplace.deployed();
  console.log("Marketplace address address:", marketplace.address);

  // // CS
  // console.log("Deploying Secondary token");
  // const SecondaryToken = await ethers.getContractFactory("SecondaryToken");
  // const secondaryToken = await SecondaryToken.deploy(
  //   "Craft Spice",
  //   "CS",
  //   deployer.address,
  //   BigNumber.from("10000000000000000000000")
  // );
  // console.log("Secondary token address:", secondaryToken.address);

  fs.writeFileSync(
    "./scripts/address.json",
    JSON.stringify({
      deployerAddress: deployer.address,
      BlastEquipmentNFT: blastEqtNFT.address,
      BlastLootBox: blastLootBox.address,
      PrimaryToken: primaryToken.address,
      Marketplace: marketplace.address,
    })
  );
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
