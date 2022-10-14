export const flipUsingMatic = async function (taskArgs: any, hre: any) {
  const contractNames = [
    'Repairing',
    'Replicator',
    'Upgrader'
  ]

  const { get } = hre.deployments

  for (const contractName of contractNames) {
    const contractAddress = await get(contractName)
    const contract = await hre.ethers.getContractFactory(contractName)
    const contractInstance = await contract.attach(contractAddress.address)

    const tx = await (await contractInstance.flipIsUsingMatic()).wait()

    console.log(`✅ [${contractName}] flipped isUsingMatic`)
    console.log(` tx: ${tx.transactionHash}`)
  }
}
