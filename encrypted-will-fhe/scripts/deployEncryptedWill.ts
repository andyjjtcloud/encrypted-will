import { ethers } from "hardhat";

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log("Deploying with:", deployer.address);

  const Factory = await ethers.getContractFactory("SimpleEncryptedWill");
  const contract = await Factory.deploy();

  await contract.waitForDeployment();

  console.log("SimpleEncryptedWill deployed at:", await contract.getAddress());
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
