import { expect } from "chai";
import { ethers } from "hardhat";
import { setup, signBuy, IBlast } from "./utils/setup";

describe("6 - Blast LootBox", function () {
  let blast: IBlast;
  let domain: any;
  before("deploying", async () => {
    blast = await setup();
  });

  // Deploy and Setup.
  it("Deploy LootBox", async function () {
    const LootBox = await ethers.getContractFactory("BlastLootBox");

    // Deploy LootBox with default URI :
    // - Name of the Lootbox : LootBox1
    // - Symbol of the Lootbox : LB1
    // - Address of the BlastEquipmentNFT contract
    // - Address of the BlastRoyaleToken (BLT) contract
    // - Address of the treasury : will receive payments
    // - Address of the Game (wallet in the backend) used to sign new Mintings (safeMinting).
    // - Amount of NFTs for every LootBox = 3
    // - Set Origin = 2
    // - URI of the Lootbox NFT :ipfs//lootid
    // - URI of the new NFTs : ipfs://equipmentid
    blast.lootbox = await LootBox.connect(blast.owner).deploy(
      "LootBox1",
      "LB1",
      blast.equipment.address,
      blast.blt.address,
      blast.treasury.address,
      blast.game.address,
      3,
      2,
      "ipfs://lootid",
      "ipfs://equipmentid"
    );
    await blast.lootbox.deployed();

    // Grant MINTER_ROLE in the BlastEquipmentNFT contract to LootBox1
    await blast.equipment
      .connect(blast.owner)
      .grantRole(blast.MINTER_ROLE, blast.lootbox.address);

    // Prepare the Domain (EIP712) to sign mintings.
    domain = {
      name: "LootBox1",
      version: "1",
      chainId: await blast.cs.getChainId(),
      verifyingContract: blast.lootbox.address,
    };
  });

  // Ready to Mint some Lootboxes.
  it("Mint Lootboxes", async function () {
    // Get the nonce (different for every address to avoid conflicts).
    const nonce = await blast.lootbox.nonce(blast.player1.address);

    // Sign the new minting : address to, number of lootboxes, total price, nonce
    const signature = await signBuy(
      // Domain of the signature
      domain,
      // Address receiveing the Lootboxes
      blast.player1.address,
      // Number of Lootboxes
      "10",
      // Price (total).
      "0",
      // Signer
      blast.game,
      // Actual Nonce for the address receiving.
      nonce
    );
    const tx = await blast.lootbox
      .connect(blast.player1)
      .safeMint(
        10,
        ethers.utils.parseUnits("0"),
        blast.player1.address,
        signature
      );
    await tx.wait();

    // 10 new boxes have been minted for player1
    expect(await blast.lootbox.balanceOf(blast.player1.address)).to.equal(10);
    // The owner of NFT (0) is player1.
    expect(await blast.lootbox.ownerOf(0)).to.equal(blast.player1.address);
  });

  it("Sign and Mint with a Price", async function () {
    const nonce = await blast.lootbox.nonce(blast.player1.address);
    const signature = await signBuy(
      domain,
      blast.player1.address,
      "5",
      "10",
      blast.game,
      nonce,
      true
    );
    await blast.blt
      .connect(blast.player1)
      .approve(blast.lootbox.address, ethers.utils.parseUnits("10"));
    const tx = await blast.lootbox
      .connect(blast.player1)
      .safeMint(
        5,
        ethers.utils.parseUnits("10"),
        blast.player1.address,
        signature
      );
    await tx.wait();
    expect(await blast.lootbox.balanceOf(blast.player1.address)).to.equal(15);
    expect(await blast.lootbox.ownerOf(0)).to.equal(blast.player1.address);
  });

  it("Reveal and open NFTs", async function () {
    expect(await blast.equipment.balanceOf(blast.player1.address)).to.equal(10);
    await expect(blast.lootbox.open([0, 1])).to.be.revertedWith(
      "Cannot Open yet"
    );
    await blast.lootbox.reveal();
    await blast.lootbox.open([0, 1]);
    expect(await blast.lootbox.balanceOf(blast.player1.address)).to.equal(13);
    expect(await blast.equipment.balanceOf(blast.player1.address)).to.equal(16);

    // Verify the origin.
    expect(await blast.equipment.attributes(15, 1)).to.equal(2);
  });

  it("Fail to open NFTs", async function () {
    await expect(blast.lootbox.open([0])).to.be.revertedWith(
      "Open nonexistent token"
    );
  });
});
