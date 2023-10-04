require("@nomicfoundation/hardhat-toolbox");
require("hardhat-gas-reporter");
require("hardhat-contract-sizer");
require("dotenv").config({ path: __dirname + "/.env" });

const { INFURA_API, DEPLOYER_PRIVATE_KEY, ETHERSCAN_API_KEY } = process.env;


/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity:{
    version: "0.8.18",
    settings: {
      optimizer: {
        enabled: true,
        runs: 2000,
      },
    },
  },
  networks: {
    hardhat: {
      initialBaseFeePerGas: 0
    },
    sepolia: {
      url: INFURA_API,
      accounts: [DEPLOYER_PRIVATE_KEY],
    },
  },
  gasReporter: {
    enabled: true,
  },
  etherscan: {
    apiKey: {
      sepolia: ETHERSCAN_API_KEY,
    },
  },
};