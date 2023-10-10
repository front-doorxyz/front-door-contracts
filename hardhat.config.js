require("@nomicfoundation/hardhat-toolbox");
require("hardhat-gas-reporter");
require("hardhat-contract-sizer");
require("dotenv").config({ path: __dirname + "/.env" });

const {
  INFURA_API, 
  DEPLOYER_PRIVATE_KEY, 
  ETHERSCAN_API_KEY,
  SKALE_ENDPOINT,
  CHAIN_ID,
  API_URL,
  BLOCKEXPLORER_URL} =
  process.env;

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
    skale: {
      url: SKALE_ENDPOINT,
      accounts: [DEPLOYER_PRIVATE_KEY],
    },
  },
  gasReporter: {
    enabled: true,
  },
  etherscan: {
    apiKey: {
      sepolia: ETHERSCAN_API_KEY,
      skale: ETHERSCAN_API_KEY,
    },
    customChains: [
      {
        network: "skale",
        chainId: parseInt(CHAIN_ID),
        urls:{
          apiURL: API_URL,
          browserURL: BLOCKEXPLORER_URL,
        }
      }
    ],
  },
};