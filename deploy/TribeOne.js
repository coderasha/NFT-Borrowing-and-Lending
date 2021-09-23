// Defining bytecode and abi from original contract on mainnet to ensure bytecode matches and it produces the same pair code hash

module.exports = async function ({ ethers, getNamedAccounts, deployments, getChainId }) {
  const { deploy } = deployments
  const { deployer } = await getNamedAccounts()

  await deploy('TribeOne', {
    from: deployer,
    log: true,
    args: [
      "0x6C641CE6A7216F12d28692f9d8b2BDcdE812eD2b",
      "0x6C641CE6A7216F12d28692f9d8b2BDcdE812eD2b",
      "0x6C641CE6A7216F12d28692f9d8b2BDcdE812eD2b",
      "0x769545212841822CF1fd628ac47d95fc838ea02F"
    ],
    deterministicDeployment: false,
  })
}

module.exports.tags = ["TribeOne", "TribeOne"];
