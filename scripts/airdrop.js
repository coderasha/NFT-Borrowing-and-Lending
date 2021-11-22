// This script is for airdrop mock on testnet
const { ethers } = require('hardhat');
const { getBigNumber } = require('./shared/utilities');

const RECEIVERS = [
  '0x9C330a97c3DD093F4b514aF6CC2f531AC0Cb084b',
'0xc3f50FDDaC41cbe50d1B8abFa2Fd18E2dc5ae10C',
'0x7b24a283ca9B037FBCF494D5941e5517a258270c',
'0x8EDf8168D75aef531B5b7869fA1bf2990811535e',
'0x8b55A84a8Cf72De8a007D96E0CdE453e672f4f5E',
'0x464cEfb76364388E38aEb80618C0EE9f8B1A1234',
'0xe661c5aB1E906850bF12e98Ff9Ae03a23b8DbF9b',
'0x5F509C7B017833f38478d1CA52025aB2a334289F',
'0x2EaD2E8677fdf1ce8Be30208bb9eCe0fb5714594',
'0x135A5E4Ef1c39028e9F0Ac1f6452Ee1dde9947f7',
'0x0ea09278CEF61652D766A31058875b8e338C2422',
'0xfCb63BebCFe671da9379b07f4AB3E428C0BC8D3C',
'0xCB8d5811c1a1b95F0a10878dE2E1B0Ba076CeD9d',
'0xBE8cf792C7081da547C0e286d79bA365b63F1109',
'0x36E0A1ea8ed55bcc757E913225e4BbdfadeEAAcF',
'0xc16f2662620b021F6a3e99bF7f601962AAb5F2b3',
'0xF977aDbd7A7C6f4B76Cfcf0b7721DCCfdb58D553',
'0x817Dd547b325FaCaf7B8B5801577D089939e6F34',
'0x43DAc997914bE7ADb996003a36154E05F2dD7017',
'0x4Df2c4c96e6E7ed4B2fcb54b924109e59A6a96D8',
'0x9962d3959680bAF00647efA1AC98F7789523AC6B',
'0x03FB741f8E128F28429B4e2595f8836f7073e121',
'0x60c8306Fc576799380c1c422820DB9451768c232',
'0xc33c1560ff81f6A57c7DaC79e1c2d327d63b0479',
'0x9E26fC72c5a33DF6e71952C6aCBEF1CfedD68951',
'0x9EDDF10Ca80CB8f96eF5eD5826A3CF39cFc618A1'
];


const CHUNK_SIZE = 50;

async function main() {
  const airdropContractAddress = "0x6F971B269B0e3b814529B802F080a27f13721E67";
  const airdropContract = await ethers.getContractAt('AirdropTribeOne', airdropContractAddress);
  const haka = '0xd8f50554055Be0276fa29F40Fb3227FE96B5D6c2';
  const from = '0x6C641CE6A7216F12d28692f9d8b2BDcdE812eD2b';

  /** validating addresses */
  for (const addr of RECEIVERS) {
    if (ethers.utils.isAddress(addr) !== true) {
      console.log(`Invalid address ${addr} - idx - ${RECEIVERS.indexOf(addr)}`);
      return;
    } else {
      console.log(`Address ${addr} is valid address`);
    }
  }
  let callReceivers = [];
  let callAmounts = [];
  let airdropIdx = 1;

  // const r1 = ['0xDEfd29b83702cC5dA21a65Eed1FEC2CEAB768074'];
  const r1 = [...RECEIVERS];
  for (const addr of r1) {
    callReceivers.push(addr);
    callAmounts.push(getBigNumber(10000));
    if (callReceivers.length === CHUNK_SIZE || r1.indexOf(addr) === r1.length - 1) {
      console.log(`Airdrop ${airdropIdx} is mining`);
      const tx = await airdropContract.airdrop(callReceivers, callAmounts, haka, from, {
        gasPrice: ethers.utils.parseUnits('80', 'gwei'), gasLimit: 4000000
      });
      await tx.wait();
      console.log('Transaction hash', tx.hash);
      console.log(`Airdrop ${airdropIdx} was mined`);
      callReceivers = [];
      callAmounts = [];
      airdropIdx++;
    }    
  }
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
