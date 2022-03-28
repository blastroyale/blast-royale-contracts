import { Given, When, Then } from "@cucumber/cucumber"
import { expect } from "chai";
// const { expect } = require('chai');

Given("The nft contract has been deployed", async function () {
  expect(await this._initialized).to.be.true;
  expect(await this.blastct.hasRole(this.minterRole, this.owner)).to.be.true;
});
