const { expect } = require('chai');
const { ethers } = require('hardhat');

describe('TribeOne', function () {
  before(async function () {
    this.TribeOne = await ethers.getContractFactory('TribeOne');
    this.AgentProxy = await ethers.getContractFactory('AgentProxy');
    this.MockERC20 = await ethers.getContractFactory('MockERC20');
    this.MockERC721 = await ethers.getContractFactory('MockERC721');
    this.MockERC1155 = await ethers.getContractFactory('MockERC1155');

    this.signers = await ethers.getSigners();
    // this.agent = this.signers[0].address;
    this.salesManager = this.signers[0];
    this.feeTo = this.signers[10].address;
  });

  beforeEach(async function () {
    this.agentProxy = await this.AgentProxy.deploy();
    this.mockUSDT = await this.MockERC20.deploy("MockUSDT", "MockUSDT"); // will be used for late fee 
    this.mockUSDC = await this.MockERC20.deploy("MockUSDC", "MockUSDC"); // wiil be used for collateral
    this.tribeOne = await this.TribeOne.deploy(
      this.agentProxy.address,
      this.salesManager.address,
      this.feeTo,
      this.mockUSDT.address
    );
  });

  it('TribeOne', async function () {});
});
