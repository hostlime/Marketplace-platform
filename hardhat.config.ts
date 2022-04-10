import * as dotenv from "dotenv";

import { HardhatUserConfig, task } from "hardhat/config";
import "@nomiclabs/hardhat-etherscan";
import "@nomiclabs/hardhat-waffle";
import "@typechain/hardhat";
import "hardhat-gas-reporter";
import "solidity-coverage";
import "@nomiclabs/hardhat-ethers";




task("starttraderound", "startTradeRound")
  .addParam("address", "The contract address on")
  .setAction(async (taskArgs, hre) => {
    const contract = await hre.ethers.getContractAt("Market", taskArgs.address)
    await contract.startTradeRound();
  });

task("startsaleround", "startSaleRound")
  .addParam("address", "The contract address on")
  .setAction(async (taskArgs, hre) => {
    const contract = await hre.ethers.getContractAt("Market", taskArgs.address)
    await contract.startSaleRound();
  });

task("registration", "registration")
  .addParam("address", "The contract address on")
  .addParam("referer", "referer")
  .setAction(async (taskArgs, hre) => {
    const contract = await hre.ethers.getContractAt("Market", taskArgs.address)
    await contract.registration(taskArgs.referer);
  });
task("removeorder", "removeOrder")
  .addParam("address", "The contract address on")
  .addParam("id", "_idOrder")
  .setAction(async (taskArgs, hre) => {
    const contract = await hre.ethers.getContractAt("Market", taskArgs.address)
    await contract.registration(taskArgs.id);
  });

dotenv.config();

// This is a sample Hardhat task. To learn how to create your own go to
// https://hardhat.org/guides/create-task.html
task("accounts", "Prints the list of accounts", async (taskArgs, hre) => {
  const accounts = await hre.ethers.getSigners();

  for (const account of accounts) {
    console.log(account.address);
  }
});

// You need to export an object to set up your config
// Go to https://hardhat.org/config/ to learn more

const config: HardhatUserConfig = {
  solidity: "0.8.4",
  networks: {
    rinkeby: {
      url: `https://eth-rinkeby.alchemyapi.io/v2/${process.env.ALCHEMY_API_KEY}`,
      accounts:
        process.env.RINKEBY_PRIVATE_KEY !== undefined ? [process.env.RINKEBY_PRIVATE_KEY] : [],
    },
    hardhat: {
      initialBaseFeePerGas: 0
    },
    bscTestnet: {
      url: "https://data-seed-prebsc-1-s1.binance.org:8545",
      chainId: 97,
      gasPrice: 20000000000,
      accounts:
        process.env.RINKEBY_PRIVATE_KEY !== undefined ? [process.env.RINKEBY_PRIVATE_KEY] : [],
    },
  },
  gasReporter: {
    enabled: process.env.REPORT_GAS !== undefined,
    currency: "USD",
  },
  etherscan: {
    apiKey: {
      rinkeby: process.env.ETHERSCAN_API_KEY,
      bscTestnet: process.env.BSCSCAN_API_KEY,
    },
  },
};

export default config;
