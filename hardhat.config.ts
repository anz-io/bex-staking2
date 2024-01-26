import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "@openzeppelin/hardhat-upgrades";
import "dotenv/config";

const config: HardhatUserConfig = {
  solidity: "0.8.20",
  etherscan: {
    apiKey: {
      blast_sepolia: "blast_sepolia", // apiKey is not required, just set a placeholder
    },
    customChains: [
      {
        network: "blast_sepolia",
        chainId: 168587773,
        urls: {
          apiURL: "https://api.routescan.io/v2/network/testnet/evm/168587773/etherscan",
          browserURL: "https://testnet.blastscan.io"
        }
      }
    ]
  },
  networks: {
    polygon: {
      url: process.env.POLYGON_RPC,
      accounts: [
        process.env.PRIVATE_KEY_ADMIN!, 
      ]
      // gas: "auto",
      // gasPrice: 150000000000, // 150Gwei
    },
    blast_sepolia: {
      url: process.env.BLAST_TEST_RPC,
      accounts: [
        process.env.PRIVATE_KEY_ADMIN!, 
      ]
    }
  }
};

export default config;