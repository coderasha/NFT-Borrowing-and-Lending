const { BigNumber } = require('@ethersproject/bignumber');
const { expect } = require('chai');
const { ethers, network } = require('hardhat');

/**
 * We assume loan currency is native coin
 */
describe('MultiSigWallet', function () {
  before(async function () {
    this.TribeOne = await ethers.getContractFactory('TribeOne');
    this.MultiSigWallet = await ethers.getContractFactory('MultiSigWallet');
    this.AssetManager = await ethers.getContractFactory('AssetManager');
    this.MockERC20 = await ethers.getContractFactory('MockERC20');
    this.MultiWalletTest = await ethers.getContractFactory('MultiWalletTest');

    this.signers = await ethers.getSigners();
    this.owners = [
      this.signers[0].address,
      this.signers[1].address,
      this.signers[2].address,
      this.signers[3].address,
      this.signers[4].address
    ];
    this.numConfirmationsRequired = 2;
    this.admin = this.signers[0];
    this.salesManager = this.signers[1];
    this.feeTo = this.signers[3];
  });

  beforeEach(async function () {
    this.feeCurrency = await this.MockERC20.deploy('MockUSDT', 'MockUSDT'); // will be used for late fee
    this.collateralCurrency = await this.MockERC20.deploy('MockUSDC', 'MockUSDC'); // wiil be used for collateral

    this.assetManager = await this.AssetManager.deploy();

    this.multiSigWallet = await (
      await this.MultiSigWallet.deploy(this.owners, this.numConfirmationsRequired)
    ).deployed();

    this.tribeOne = await (
      await this.TribeOne.deploy(
        this.salesManager.address,
        this.feeTo.address,
        this.feeCurrency.address,
        this.multiSigWallet.address,
        this.assetManager.address
      )
    ).deployed();

    this.multiWalletTest = await (await this.MultiWalletTest.deploy()).deployed();

    // await this.tribeOne.transferOwnership(this.multiSigWallet.address);

    // Transfering 10 ETH to TribeOne
    // await ethers.provider.send('eth_sendTransaction', [
    //   { from: this.signers[0].address, to: this.tribeOne.address, value: getBigNumber(10).toHexString() }
    // ]);
  });

  it('Trying setSettings function in TribeOne', async function () {
    const owner = await this.tribeOne.owner();
    console.log(`owner ${this.multiSigWallet.address} ${owner}`);
    console.log(this.feeTo.address);
    // 9fbd4a42  =>  setSettings(address,uint256,uint256,address)

    const encodedCallData = this.tribeOne.interface.encodeFunctionData('setSettings', [
      this.signers[0].address,
      10,
      10,
      this.signers[1].address,
      this.signers[1].address
    ]);

    const txIdx = 0;
    await expect(this.multiSigWallet.submitTransaction(this.tribeOne.address, 0, encodedCallData))
      .to.emit(this.multiSigWallet, 'SubmitTransaction')
      .withArgs(this.signers[0].address, txIdx, this.tribeOne.address, 0, encodedCallData);

    await expect(this.multiSigWallet.confirmTransaction(txIdx, false))
      .to.emit(this.multiSigWallet, 'ConfirmTransaction')
      .withArgs(this.signers[0].address, txIdx);

    await expect(this.multiSigWallet.executeTransaction(txIdx)).to.be.revertedWith('cannot execute tx');

    await expect(this.multiSigWallet.confirmTransaction(txIdx, false)).to.be.revertedWith('tx already confirmed');

    await expect(this.multiSigWallet.connect(this.signers[1]).confirmTransaction(txIdx, false))
      .to.emit(this.multiSigWallet, 'ConfirmTransaction')
      .withArgs(this.signers[1].address, txIdx);

    // await expect(this.multiSigWallet.connect(this.signers[1]).executeTransaction(txIdx))
    //   .to.emit(this.multiSigWallet, 'ExecuteTransaction')
    //   .withArgs(this.signers[1].address, txIdx);

    await expect(this.multiSigWallet.connect(this.signers[1]).executeTransaction(txIdx))
      .to.emit(this.tribeOne, 'SettingsUpdate')
      .withArgs(
        this.signers[0].address,
        BigNumber.from(10),
        BigNumber.from(10),
        this.signers[1].address,
        this.signers[1].address
      );

    await expect(this.multiSigWallet.executeTransaction(txIdx)).to.be.revertedWith('tx already executed');
  });

  it('Trying nonPayable function call with MultiWalletTest.sol', async function () {
    const encodedNonPayableCallData = this.multiWalletTest.interface.encodeFunctionData('nonPayableFunction', [
      this.signers[0].address
    ]);

    await this.multiSigWallet.submitTransaction(this.multiWalletTest.address, 0, encodedNonPayableCallData);
  });

  it('Trying payable function call with MultiWalletTest.sol', async function () {
    // const encodedPayableCallData = this.multiWalletTest.interface.encodeFunctionData('payableFunction', [
    //   this.signers[0].address,
    //   getBigNumber(2)
    // ]);
    // await this.multiSigWallet.submitTransaction(this.multiSigWallet.address, getBigNumber(2), encodedPayableCallData, { value: getBigNumber(2) })
  });
});
