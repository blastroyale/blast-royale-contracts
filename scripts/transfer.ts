import { ethers } from "hardhat";
import fs from "fs";

const BlastEquipmentNFTContract = require("../artifacts/contracts/BlastEquipmentNFT.sol/BlastEquipmentNFT.json");
const MarketplaceContract = require("../artifacts/contracts/Marketplace.sol/Marketplace.json");

async function main() {
  const _address = fs.readFileSync("./scripts/address.json", {
    encoding: "utf8",
    flag: "r",
  });
  const addresses = JSON.parse(_address);
  if (!addresses.BlastEquipmentNFT) return;
  if (!addresses.Marketplace) return;

  const [deployer] = await ethers.getSigners();

  console.log("\n** BlastEquipmentNFTContract");
  const contract = new ethers.Contract(
    addresses.BlastEquipmentNFT,
    BlastEquipmentNFTContract.abi,
    deployer
  );

  const marketplaceContract = new ethers.Contract(
    addresses.Marketplace,
    MarketplaceContract.abi,
    deployer
  );

  for (let i = 3; i <= 9; i++) {
    const tx = await contract.approve(addresses.Marketplace, i);
    await tx.wait();

    console.log("approved token " + i);
    const listTx = await marketplaceContract.addListing(
      i,
      1000000000000000 * i
    );
    await listTx.wait();
    console.log("listed Token " + i);
  }
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
