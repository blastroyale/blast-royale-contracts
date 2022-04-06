import { ethers } from "hardhat";
import fs from "fs";

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

  const urlBase = "http://flgmarketplacestorage.z33.web.core.windows.net";

  console.log(deployer.address);
  const _uris = [
    `${urlBase}/nftmetadata/0/0/12bc35030f8fb0a40f9e1ae81489b9093a67c4c6b1c79b2cb7f0ccd1f8e22cfd.json`,
    `${urlBase}/nftmetadata/0/0/566ba141d73f04c1c5dfbde107b5ccdcd19ba37aa0001dbf050814841bc587ea.json`,
    `${urlBase}/nftmetadata/0/0/6df12f3cdf1ab947524adf6c33190a6a0ca62b557ea0c189dd095003a31ea044.json`,
    `${urlBase}/nftmetadata/0/0/d3ad39f68e470be5a287504e21651f71b76d888713dd233c03c27c0d47aaf5d9.json`,
    `${urlBase}/nftmetadata/0/0/0c4f06c27c3a4c25eaa9d42939b6f229f6b58faffb7d25b713bcc89e21fce223.json`,
    `${urlBase}/nftmetadata/0/0/e7c43ce40ab9c90ec473a78fbd0e9bbf900e7d2ca27690bf06674c826ea76eb6.json`,
    `${urlBase}/nftmetadata/0/0/5da97d2c8889233dedc0288edb39b657637245c3ec76b41d6d3284bc23d72661.json`,
    `${urlBase}/nftmetadata/0/0/9340fdd8b9ba09c90a752f1d32f9425a54206ed9801ea3cb52168ce75f5ebdb1.json`,
    `${urlBase}/nftmetadata/0/0/44d87bea41b4e8579eb0b2dd37c1f9dd2753a6e5d16ebc24da865382aec8ffdf.json`,
    `${urlBase}/nftmetadata/0/0/011fdaeeb3cf365090ee78d90ad76e792478674eb5b525d15f5f5b05790a1d59.json`,
  ];
  const _hash = [
    "0x12bc35030f8fb0a40f9e1ae81489b9093a67c4c6b1c79b2cb7f0ccd1f8e22cfd",
    "0x566ba141d73f04c1c5dfbde107b5ccdcd19ba37aa0001dbf050814841bc587ea",
    "0x6df12f3cdf1ab947524adf6c33190a6a0ca62b557ea0c189dd095003a31ea044",
    "0xd3ad39f68e470be5a287504e21651f71b76d888713dd233c03c27c0d47aaf5d9",
    "0x0c4f06c27c3a4c25eaa9d42939b6f229f6b58faffb7d25b713bcc89e21fce223",
    "0xe7c43ce40ab9c90ec473a78fbd0e9bbf900e7d2ca27690bf06674c826ea76eb6",
    "0x5da97d2c8889233dedc0288edb39b657637245c3ec76b41d6d3284bc23d72661",
    "0x9340fdd8b9ba09c90a752f1d32f9425a54206ed9801ea3cb52168ce75f5ebdb1",
    "0x44d87bea41b4e8579eb0b2dd37c1f9dd2753a6e5d16ebc24da865382aec8ffdf",
    "0x011fdaeeb3cf365090ee78d90ad76e792478674eb5b525d15f5f5b05790a1d59",
  ];

  await contract.safeMint(deployer.address, _uris, _hash);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
