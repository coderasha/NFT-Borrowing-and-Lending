// Defining bytecode and abi from original contract on mainnet to ensure bytecode matches and it produces the same pair code hash

module.exports = async function ({ ethers, getNamedAccounts, deployments, getChainId }) {
  const { deploy } = deployments
  const { deployer } = await getNamedAccounts()

  await deploy('MultiSigWallet', {
    from: deployer,
    log: true,
    args: [
      [
        "0x6C641CE6A7216F12d28692f9d8b2BDcdE812eD2b",
        "0xDEfd29b83702cC5dA21a65Eed1FEC2CEAB768074",
        "0x44CE231344473c2f6f1e263d338F4Bb3f7168236",
        "0xFE9fAa12150C85708AF89132057345177B507D68"
      ],
      2
    ],
    deterministicDeployment: false,
  })
}

module.exports.tags = ["MultiSigWallet", "TribeOne"];
