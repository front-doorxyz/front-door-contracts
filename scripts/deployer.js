// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// You can also run a script with `npx hardhat run <script>`. If you do that, Hardhat
// will compile your contracts, add the Hardhat Runtime Environment's members to the
// global scope, and execute the script.
const hre = require("hardhat");

async function main() {
  const frontDoorWallet = "0xb29bd8e0E273843AaA92BEAC6DbE0EC788e1852f";

  const fndrToken = await hre.ethers.deployContract("FrontDoorToken", []);
  await fndrToken.waitForDeployment();
  const fndrTokenAddress = fndrToken.target;
  console.log("Deploying Contracts...");
  console.log("Front Door Token deployed to: ", fndrTokenAddress);

  const fndrFaucet = await hre.ethers.deployContract("FNDR_Faucet", [
    fndrTokenAddress,
  ]);
  await fndrFaucet.waitForDeployment();
  const fndrFaucetAddress = fndrFaucet.target;

  console.log("Front Door Faucet deployed to: ", fndrFaucetAddress);

  console.log("Configuring roles in Front Door Token...");

  await fndrToken.setFaucet(fndrFaucetAddress);

  const recruitment = await hre.ethers.deployContract("Recruitment", [
    fndrTokenAddress,
    frontDoorWallet,
  ]);
  await recruitment.waitForDeployment();
  console.log(
    "Front Door Recruiter Contract deployed to: ",
    recruitment.target
  );

}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
