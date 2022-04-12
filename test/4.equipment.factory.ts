import { expect } from "chai";
import { ethers } from "hardhat";
import { setup, IBlast, getBalance } from "./utils/setup";

describe("4 - Craft & Repair Equipment", function () {
  let blast: IBlast;

  before("deploying", async () => {
    blast = await setup();
  });

  it("Repair one NFT", async () => {
    // Initial parameters.
    let repairCount = await blast.equipment.attributes(0, 2);
    const repairTS1 = await blast.equipment.attributes(0, 3);
    expect(repairCount).to.equal(0);
    let balance = await getBalance(blast.blt, blast.player1.address);
    expect(balance).to.equal(1000);
    balance = await getBalance(blast.cs, blast.player1.address);
    expect(balance).to.equal(1000);

    // Approve BLT spending
    await blast.blt
      .connect(blast.player1)
      .approve(blast.factory.address, ethers.utils.parseUnits("2"));

    // Approve CS burning
    await blast.cs
      .connect(blast.player1)
      .approve(blast.factory.address, ethers.utils.parseUnits("10"));

    // Repair.
    await expect(blast.factory.connect(blast.player1).repair(0))
      .to.emit(blast.factory, "Repaired")
      .withArgs(blast.player1.address, 0);

    // repairCount incremented, repairTS updated, BLT spent and CS burned.
    repairCount = await blast.equipment.attributes(0, 2);
    expect(repairCount).to.equal(1);
    const repairTS2 = await blast.equipment.attributes(0, 3);
    expect(repairTS2 > repairTS1).to.equal(true);

    // Check Balances : player1, cs (burned) and treasury
    balance = await getBalance(blast.blt, blast.player1.address);
    expect(balance).to.equal(998);
    balance = await getBalance(blast.cs, blast.player1.address);
    expect(balance).to.equal(990);
    balance = await getBalance(blast.blt, blast.treasury.address);
    expect(balance).to.equal(2);
    const supply = await blast.cs.totalSupply();
    expect(ethers.utils.formatUnits(supply, 18)).to.equal("99999990.0");
  });

  it("Cannot repair NFT - Not the owner", async () => {
    await expect(
      blast.factory.connect(blast.game).repair(0)
    ).to.be.revertedWith("Only the owner can repair");
  });

  it("Change Treasury address", async () => {
    await expect(
      blast.factory.connect(blast.owner).setTreasury(blast.treasury2.address)
    )
      .to.emit(blast.factory, "Treasury")
      .withArgs(blast.treasury2.address);
  });

  it("Fails to repair NFT - Too many repairs", async () => {
    await blast.blt
      .connect(blast.player1)
      .approve(blast.factory.address, ethers.utils.parseUnits("8"));
    await blast.cs
      .connect(blast.player1)
      .approve(blast.factory.address, ethers.utils.parseUnits("40"));
    await blast.factory.connect(blast.player1).repair(0);
    await blast.factory.connect(blast.player1).repair(0);
    await blast.factory.connect(blast.player1).repair(0);
    await blast.factory.connect(blast.player1).repair(0);
    await expect(
      blast.factory.connect(blast.player1).repair(0)
    ).to.be.revertedWith("Max repair reached");
  });

  it("Craft a new NFT", async () => {
    // Initial parameters.
    let craftCount1 = await blast.equipment.attributes(0, 1);
    expect(craftCount1).to.equal(0);
    let craftCount2 = await blast.equipment.attributes(1, 1);
    expect(craftCount2).to.equal(0);

    // Approve BLT spending
    await blast.blt
      .connect(blast.player1)
      .approve(blast.factory.address, ethers.utils.parseUnits("5"));

    // Approve CS burning
    await blast.cs
      .connect(blast.player1)
      .approve(blast.factory.address, ethers.utils.parseUnits("15"));

    // Repair.
    await expect(blast.factory.connect(blast.player1).craft(0, 1))
      .to.emit(blast.factory, "Crafted")
      .withArgs(blast.player1.address, 0, 1);

    // repairCount incremented, repairTS updated, BLT spent and CS burned.
    craftCount1 = await blast.equipment.attributes(0, 1);
    expect(craftCount1).to.equal(1);
    craftCount2 = await blast.equipment.attributes(1, 1);
    expect(craftCount2).to.equal(1);

    // Check Balances : player1, cs (burned) and treasury
    let balance = await getBalance(blast.blt, blast.player1.address);
    expect(balance).to.equal(985);
    balance = await getBalance(blast.cs, blast.player1.address);
    expect(balance).to.equal(935);
    balance = await getBalance(blast.blt, blast.treasury2.address);
    expect(balance).to.equal(13);
    const supply = await blast.cs.totalSupply();
    expect(ethers.utils.formatUnits(supply, 18)).to.equal("99999935.0");
  });

  it("Change Prices", async () => {
    await expect(
      blast.factory
        .connect(blast.owner)
        .setPrices(
          ethers.utils.parseUnits("1"),
          ethers.utils.parseUnits("50"),
          ethers.utils.parseUnits("2"),
          ethers.utils.parseUnits("25")
        )
    )
      .to.emit(blast.factory, "PricesChanged")
      .withArgs(
        ethers.utils.parseUnits("1"),
        ethers.utils.parseUnits("50"),
        ethers.utils.parseUnits("2"),
        ethers.utils.parseUnits("25")
      );
  });
});
