import { ethers } from "hardhat";
import fs from "fs";
import path from "path";

// const uri = "https://blastroyale.com/nft/";

describe("Blast LootBox Contract", function () {
  it("Open function test", async function () {
    const [owner] = await ethers.getSigners();
    // BlastEquipment NFT Deploying
    const BlastEquipmentToken = await ethers.getContractFactory(
      "BlastEquipmentNFT"
    );
    const bet = await BlastEquipmentToken.connect(owner).deploy(
      "Blast Equipment",
      "BLT"
    );
    await bet.deployed();

    // BlastLootbox NFT Deploying
    const BlastLootBox = await ethers.getContractFactory("BlastLootBox");
    const blb = await BlastLootBox.connect(owner).deploy(
      "Blast LootBox",
      "BLB",
      bet.address
    );
    await blb.deployed();

    const hashContent = fs.readFileSync(
      path.resolve(__dirname, "token_hash_links.json"),
      {
        encoding: "utf8",
        flag: "r",
      }
    );
    const data = JSON.parse(hashContent);
    const _uris = data.map((item: any) => item.url);
    const _hash = data.map((item: any) => "0x" + item.hash);

    const chunkSize = 80;
    for (let i = 0; i < _uris.length; i += chunkSize) {
      const chunkUri = _uris.slice(i, i + chunkSize);
      const chunkHash = _hash.slice(i, i + chunkSize);

      const tx = await bet.safeMint(blb.address, chunkUri, chunkHash, chunkUri);
      await tx.wait();
    }
  });
});
