import { expect } from "chai";
import { ethers } from "hardhat";

// const uri = "https://blastroyale.com/nft/";

describe("Blast LootBox Contract", function () {
  let owner: any;
  let player1: any;
  let player2: any;
  let bet: any;
  let blb: any;

  before("deploying", async () => {
    const signers = await ethers.getSigners();
    owner = signers[0];
    player1 = signers[1];
    player2 = signers[2];
  });

  it("Open function test", async function () {
    // BlastEquipment NFT Deploying
    const BlastEquipmentToken = await ethers.getContractFactory(
      "BlastEquipmentNFT"
    );
    bet = await BlastEquipmentToken.connect(owner).deploy(
      "Blast Equipment",
      "BLT"
    );
    await bet.deployed();

    // BlastLootbox NFT Deploying
    const BlastLootBox = await ethers.getContractFactory("BlastLootBox");
    blb = await BlastLootBox.connect(owner).deploy(
      "Blast LootBox",
      "BLB",
      bet.address
    );
    await blb.deployed();

    // Equipment NFT minting process
    const mintTx = await bet
      .connect(owner)
      .safeMint(
        blb.address,
        ["ipfs://111", "ipfs://222", "ipfs://333"],
        [
          ethers.utils.keccak256("0x1000"),
          ethers.utils.keccak256("0x2000"),
          ethers.utils.keccak256("0x3000"),
        ],
        ["ipfs://111_real", "ipfs://222_real", "ipfs://333_real"]
      );
    await mintTx.wait();
    // Grant REVEAL_ROLE to Lootbox contract
    const REVEAL_ROLE = await bet.REVEAL_ROLE();
    await bet.connect(owner).grantRole(REVEAL_ROLE, blb.address);

    // Lootbox Minting to address with Equipment NFT ids [0, 1, 2]
    const tx = await blb.connect(owner).safeMint(
      [owner.address],
      ["ipfs://111"],
      [
        {
          token0: ethers.BigNumber.from("0"),
          token1: ethers.BigNumber.from("1"),
          token2: ethers.BigNumber.from("2"),
        },
      ],
      1
    );
    await tx.wait();

    // Lootbox contract has 3 Equipment NFT items
    expect(await bet.balanceOf(blb.address)).to.equal(3);
    // Owner don't have Equipment NFT
    expect(await bet.balanceOf(owner.address)).to.equal(0);
    // Owner only have 1 Lootbox NFT
    expect(await blb.balanceOf(owner.address)).to.equal(1);

    // Owner opens the Lootbox
    const openTx = await blb.connect(owner).open(0);
    await openTx.wait();

    // Now, 3 Equipment items which Lootbox contract had transferred to Owner
    expect(await bet.balanceOf(blb.address)).to.equal(0);
    // Owner balance of Equipment NFT is 3
    expect(await bet.balanceOf(owner.address)).to.equal(3);
    // Owner has no Lootbox NFT because it's already burnt
    expect(await blb.balanceOf(owner.address)).to.equal(0);

    // Reveal test

    expect(await bet.tokenURI(0)).to.equal("ipfs://111_real");
    expect(await bet.tokenURI(1)).to.equal("ipfs://222_real");
    expect(await bet.tokenURI(2)).to.equal("ipfs://333_real");
  });

  it("Open multiple lootbox items", async () => {
    // Equipment NFT minting process
    const mintTx1 = await bet
      .connect(owner)
      .safeMint(
        blb.address,
        [
          "ipfs://111",
          "ipfs://222",
          "ipfs://333",
          "ipfs://444",
          "ipfs://555",
          "ipfs://666",
        ],
        [
          ethers.utils.keccak256("0x1000"),
          ethers.utils.keccak256("0x2000"),
          ethers.utils.keccak256("0x3000"),
          ethers.utils.keccak256("0x4000"),
          ethers.utils.keccak256("0x5000"),
          ethers.utils.keccak256("0x6000"),
        ],
        [
          "ipfs://111_real",
          "ipfs://222_real",
          "ipfs://333_real",
          "ipfs://444_real",
          "ipfs://555_real",
          "ipfs://666_real",
        ]
      );
    await mintTx1.wait();

    const tx = await blb.connect(owner).safeMint(
      [player1.address, player1.address],
      ["ipfs://111", "ipfs://222"],
      [
        {
          token0: ethers.BigNumber.from("3"),
          token1: ethers.BigNumber.from("4"),
          token2: ethers.BigNumber.from("5"),
        },
        {
          token0: ethers.BigNumber.from("6"),
          token1: ethers.BigNumber.from("7"),
          token2: ethers.BigNumber.from("8"),
        },
      ],
      1
    );
    await tx.wait();

    expect(await blb.balanceOf(player1.address)).to.eq(2);

    const openTx = await blb.connect(owner).openTo(1, player1.address);
    await openTx.wait();
  });

  it("Can create an empty lootbox with no Blast Equipment minted", async () => {

    // creating a lootbox with tokens that do not exist  
    const tx = await blb.connect(owner).safeMint(
      [player2.address],
      ["ipfs://999"],
      [
        {
          token0: ethers.BigNumber.from("123"),
          token1: ethers.BigNumber.from("789"),
          token2: ethers.BigNumber.from("999"),
        },
      ],
      1
    );
    await tx.wait();
    

    expect(await blb.balanceOf(player2.address)).to.eq(1);

    expect(blb.connect(owner).openTo(3, player2.address)).to.be.revertedWith("ERC721: operator query for nonexistent token")
    // player should not receive any equipment NFT
    expect(await bet.balanceOf(player2.address)).to.equal(0);
  });
});
