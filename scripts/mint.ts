import { ethers } from "hardhat";
import fs from "fs";
import axios from "axios";

const BlastEquipmentNFTContract = require("../artifacts/contracts/BlastEquipmentNFT.sol/BlastEquipmentNFT.json");

async function main() {
  const _address = fs.readFileSync("./scripts/address.json", {
    encoding: "utf8",
    flag: "r",
  });
  const addresses = JSON.parse(_address);
  if (!addresses.BlastEquipmentNFT) return;

  const [deployer] = await ethers.getSigners();

  console.log("\n** BlastEquipmentNFTContract");
  const contract = new ethers.Contract(
    addresses.BlastEquipmentNFT,
    BlastEquipmentNFTContract.abi,
    deployer
  );

  const { data } = await axios.get(
    "http://flgmarketplacestorage.z33.web.core.windows.net/nftmetadata/0/0/tokenurl_hash_links.json"
  );
  if (!data) return;
  const _uris = Object.keys(data).map((uri) => uri);
  const _hash = Object.keys(data).map((uri) => "0x" + data[uri]);
  const tx = await contract.safeMint(deployer.address, _uris, _hash);
  await tx.wait();

  console.log(`Minted ${_uris.length} NFT items`);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
