"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const cucumber_1 = require("@cucumber/cucumber");
const chai_1 = require("chai");
// const { expect } = require('chai');
(0, cucumber_1.Given)("The nft contract has been deployed", async function () {
    (0, chai_1.expect)(await this._initialized).to.be.true;
    (0, chai_1.expect)(await this.blastct.hasRole(this.minterRole, this.owner)).to.be.true;
});
