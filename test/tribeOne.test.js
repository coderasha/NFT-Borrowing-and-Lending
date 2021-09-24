const { expect } = require('chai');
const { ethers } = require('hardhat');
const { ZERO_ADDRESS, getBigNumber, NFT_TYPE, STATUS } = require('../scripts/shared/utilities');

/**
 * We assume loan currency is native coin
 */
describe('TribeOne', function () {
  before(async function () {
    this.TribeOne = await ethers.getContractFactory('TribeOne');
    this.AgentProxy = await ethers.getContractFactory('AgentProxy');
    this.MockERC20 = await ethers.getContractFactory('MockERC20');
    this.MockERC721 = await ethers.getContractFactory('MockERC721');
    this.MockERC1155 = await ethers.getContractFactory('MockERC1155');

    this.signers = await ethers.getSigners();
    this.admin = this.signers[0];
    this.salesManager = this.signers[1];
    this.agent = this.signers[2];
    this.feeTo = this.signers[3];
    this.alice = this.signers[4];
    this.bob = this.signers[5];
    this.todd = this.signers[6];
  });

  beforeEach(async function () {
    this.agentProxy = await this.AgentProxy.deploy();
    this.feeCurrency = await this.MockERC20.deploy('MockUSDT', 'MockUSDT'); // will be used for late fee
    this.collateralCurrency = await this.MockERC20.deploy('MockUSDC', 'MockUSDC'); // wiil be used for collateral
    this.tribeOne = await this.TribeOne.deploy(
      this.agentProxy.address,
      this.salesManager.address,
      this.feeTo.address,
      this.feeCurrency.address
    );

    // Preparing NFT
    this.erc721NFT = await this.MockERC721.deploy('TribeOne', 'TribeOne');
    this.erc1155NFT = await this.MockERC1155.deploy();
    await this.erc721NFT.batchMintTo(this.agent.address, 10);

    // Adding agent
    await this.agentProxy.addAgent(this.agent.address);

    // Transfering 10 ETH to TribeOne
    await ethers.provider.send('eth_sendTransaction', [
      { from: this.signers[0].address, to: this.tribeOne.address, value: getBigNumber(10).toHexString() }
    ]);

    // Transfering collateralCurrency (USDC) to users
    await this.collateralCurrency.transfer(this.alice.address, getBigNumber(1000000));
    await this.collateralCurrency.transfer(this.bob.address, getBigNumber(1000000));
    await this.collateralCurrency.transfer(this.todd.address, getBigNumber(1000000));
  });

  it('Should create and approve loan', async function () {
    const _loanRules = [6, 2500, 300];
    const _currencies = [ZERO_ADDRESS, this.collateralCurrency.address];
    const nftAddressArray = [this.erc721NFT.address, this.erc721NFT.address, this.erc1155NFT.address];
    const _amounts = [getBigNumber(1), getBigNumber(100)];
    const nftTokenIdArray = [1, 2, 1];
    const nftTokenTypeArray = [NFT_TYPE.ERC721, NFT_TYPE.ERC721, NFT_TYPE.ERC1155];

    console.log('Alice is creating loan...');
    await this.collateralCurrency.connect(this.alice).approve(this.tribeOne.address, getBigNumber(100000000));
    await expect(
      this.tribeOne
        .connect(this.alice)
        .createLoan(_loanRules, _currencies, nftAddressArray, _amounts, nftTokenIdArray, nftTokenTypeArray, {
          from: this.alice.address,
          value: getBigNumber(1)
        })
    )
      .to.emit(this.tribeOne, 'LoanCreated')
      .withArgs(1, this.alice.address);

    console.log('Approving loan...');
    const loanId = 1;
    const amount = getBigNumber(2);
    await expect(
      this.agentProxy
        .connect(this.agent)
        .approveLoan(this.tribeOne.address, loanId, amount, { from: this.agent.address })
    )
      .to.emit(this.tribeOne, 'LoanApproved')
      .withArgs(loanId, this.agent.address, ZERO_ADDRESS, amount);
  });

  describe('Loan actions', function () {
    beforeEach(async function () {
      const _loanRules = [6, 2500, 300];
      const _currencies = [ZERO_ADDRESS, this.collateralCurrency.address];
      const nftAddressArray = [this.erc721NFT.address, this.erc721NFT.address, this.erc1155NFT.address];
      const _amounts = [getBigNumber(1), getBigNumber(100)];
      const nftTokenIdArray = [1, 2, 1];
      const nftTokenTypeArray = [NFT_TYPE.ERC721, NFT_TYPE.ERC721, NFT_TYPE.ERC1155];
      await this.collateralCurrency.connect(this.alice).approve(this.tribeOne.address, getBigNumber(100000000));
      await expect(
        this.tribeOne
          .connect(this.alice)
          .createLoan(_loanRules, _currencies, nftAddressArray, _amounts, nftTokenIdArray, nftTokenTypeArray, {
            from: this.alice.address,
            value: getBigNumber(1)
          })
      )
        .to.emit(this.tribeOne, 'LoanCreated')
        .withArgs(1, this.alice.address);

      this.loanId = 1;
      const amount = getBigNumber(2);
      await expect(
        this.agentProxy
          .connect(this.agent)
          .approveLoan(this.tribeOne.address, this.loanId, amount, { from: this.agent.address })
      )
        .to.emit(this.tribeOne, 'LoanApproved')
        .withArgs(this.loanId, this.agent.address, ZERO_ADDRESS, amount);

      this.createdLoan = await this.tribeOne.loans(1);
    });

    it('Should return callateral and fund amount to borrower', async function () {
      const loanAmount = this.createdLoan.loanAsset.amount;
      await expect(
        this.agentProxy
          .connect(this.agent)
          .relayNFT(this.tribeOne.address, this.loanId, false, { value: loanAmount })
      )
        .to.emit(this.tribeOne, 'NFTRelayed')
        .withArgs(this.loanId, this.agent.address, false);
    });
    it('Should relay NFT to TribeOne', async function () {
      // setApprovalForAll

      // const nftTokenTypeArray = this.createLoan.nftTokenTypeArray;
      // const nftAddressArray = this.createLoan.nftAddressArray;
      // const nftTokenIdArray = [1, 2, 1];
      const nftTokenTypeArray = [NFT_TYPE.ERC721, NFT_TYPE.ERC721, NFT_TYPE.ERC1155];
      const nftTokenAddressArray = [this.erc721NFT.address, this.erc721NFT.address, this.erc1155NFT.address];

      // Approving
      for (let ii = 0; ii < nftTokenAddressArray.length; ii++) {
        const nftContract = nftTokenTypeArray[ii] == NFT_TYPE.ERC721
          ? await this.MockERC721.attach(nftTokenAddressArray[ii])
          : await this.MockERC1155.attach(nftTokenAddressArray[ii]);
        await nftContract.connect(this.agent).setApprovalForAll(this.tribeOne.address, true);
      }
      //[NFT_TYPE.ERC721, NFT_TYPE.ERC721, NFT_TYPE.ERC1155];
      await this.agentProxy
          .connect(this.agent)
          .relayNFT(this.tribeOne.address, this.loanId, true);
    })
  });
});
