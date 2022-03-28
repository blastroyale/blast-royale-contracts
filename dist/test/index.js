"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const chai_1 = require("chai");
const hardhat_1 = require("hardhat");
describe("Blast Token", function () {
    it("Should return the new greeting once it's changed", async function () {
        const [owner, addr1, addr2] = await hardhat_1.ethers.getSigners();
        const BlastToken = await hardhat_1.ethers.getContractFactory("BlastToken");
        const blt = await BlastToken.deploy("Blast Token", "BLT", owner.address, hardhat_1.ethers.utils.parseEther("100000000"));
        await blt.deployed();
        let tx = await blt.mint(addr1.address, hardhat_1.ethers.utils.parseEther("100"));
        await tx.wait();
        tx = await blt.mint(addr2.address, hardhat_1.ethers.utils.parseEther("500"));
        await tx.wait();
        // wait until the transaction is mined
        (0, chai_1.expect)(await blt.balanceOf(addr1.address)).to.equal(hardhat_1.ethers.utils.parseEther("100"));
    });
});
