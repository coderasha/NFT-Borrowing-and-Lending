const { ethers } = require('hardhat');
const { BigNumber } = ethers;
const ZERO_ADDRESS = '0x0000000000000000000000000000000000000000';

const NFT_TYPE = {
  ERC721: 0,
  ERC1155: 1
};

const STATUS = {
  AVOID_ZERO: 0, // just for avoid zero
  LISTED: 1, // after the loan have been created --> the next status will be APPROVED
  APPROVED: 2, // in this status the loan has a lender -- will be set after approveLoan(). loan fund => borrower
  LOANACTIVED: 3, // NFT was brought from opensea by agent and staked in TribeOne - relayNFT()
  LOANPAID: 4, // loan was paid fully but still in TribeOne
  WITHDRAWN: 5, // the final status, the collateral returned to the borrower or to the lender withdrawNFT()
  FAILED: 6, // NFT buying order was failed in partner's platform such as opensea...
  CANCELLED: 7, // only if loan is LISTED - cancelLoan()
  DEFAULTED: 9, // Grace period = 15 days were passed from the last payment schedule
  LIQUIDATION: 10, // NFT was put in marketplace
  POSTLIQUIDATION: 11, /// NFT was sold
  RESTWIDRAWN: 12, // user get back the rest of money from the money which NFT set is sold in marketplace
  RESTLOCKED: 13 // Rest amount was forcely locked because he did not request to get back with in 2 weeks (GRACE PERIODS)
};

// Defaults to e18 using amount * 10^18
function getBigNumber(amount, decimals = 18) {
  return BigNumber.from(amount).mul(BigNumber.from(10).pow(decimals));
}

module.exports = {
  ZERO_ADDRESS,
  NFT_TYPE,
  STATUS,
  getBigNumber
};
