async function main() {
 
  const [deployer] = await ethers.getSigners();
  
  console.log("Deploying contracts with the account:", deployer.address);
  console.log("Account balance:", (await deployer.getBalance()).toString());

  // NFT MARKETPLACE 
  const Marketplace = await ethers.getContractFactory("BlastNFT");
  const marketplace = await Marketplace.deploy("Blast Royale NFT", "BRW", "http://www.google.com.br");
  await marketplace.deployed();
  console.log("Marketplace address address:", marketplace.address);

  // BLT
  console.log("Deploying primary token");
  const PrimaryToken = await ethers.getContractFactory("PrimaryToken");
  const primaryToken = await PrimaryToken.deploy("Blast Token", "BLT", deployer.address, 10000);
  console.log("Primary token address:", primaryToken.address);

  // CS
  console.log("Deploying Secondary token");
  const SecondaryToken = await ethers.getContractFactory("SecondaryToken");
  const secondaryToken = await SecondaryToken.deploy("Craft Spice", "CS", deployer.address, 10000);
  console.log("Secondary token address:", primaryToken.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
