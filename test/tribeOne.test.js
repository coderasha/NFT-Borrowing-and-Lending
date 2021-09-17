const { expect } = require('chai');
const { ethers } = require('hardhat');

describe('TribeOne', function () {
  before(async function () {
    this.TribeOne = await ethers.getContractFactory('TribeOne');

    this.signers = await ethers.getSigners();
  });

  beforeEach(async function () {
    this.tribeOne = await this.TribeOne.deploy();
  });

  it('TribeOne', async function () {});
});
