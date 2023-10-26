/* eslint-disable max-len */
/* eslint-disable require-jsdoc */
// We require the Hardhat Runtime Environment explicitly here. This is optional
// eslint-disable-next-line max-len
// but useful for running the script in a standalone fashion through `node <script>`.
//
// You can also run a script with `npx hardhat run <script>`. If you do that, Hardhat
// will compile your contracts, add the Hardhat Runtime Environment's members to the
// global scope, and execute the script.
const hre = require('hardhat');

async function main() {
  const frontDoorWallet = '0xb29bd8e0E273843AaA92BEAC6DbE0EC788e1852f';
  const fndrTokenAddress = '0x53736EdEa0B813f0E95f10bac6B91876ed8114db';

  const recruitment = await hre.ethers.deployContract('Recruitment', [
    fndrTokenAddress,
    frontDoorWallet,
  ]);
  await recruitment.waitForDeployment();
  console.log(
      'Front Door Recruiter Contract deployed to: ',
      recruitment.target,
  );
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
