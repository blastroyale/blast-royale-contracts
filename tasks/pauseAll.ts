export const pauseAll = async function (taskArgs: any, hre: any) {
  const contractNames = [
    'Repairing',
    'Replicator',
    'Scrapper',
    'Upgrader'
  ]

  const { get } = hre.deployments

  for (const contractName of contractNames) {
    const contractAddress = await get(contractName)
    const contract = await hre.ethers.getContractFactory(contractName)
    const contractInstance = await contract.attach(contractAddress.address)

    const paused = await contractInstance.paused()
    if (!paused) {
      const tx = await (await contractInstance.pause(true)).wait()

      console.log(`✅ [${contractName}] paused at txHash: ${tx.transactionHash}`)
    }
  }
}
