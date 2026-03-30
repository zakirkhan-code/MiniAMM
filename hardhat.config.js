import "@nomicfoundation/hardhat-toolbox";

export default {
  solidity: {
    version: "0.8.26",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
    },
  },
  paths: {
    sources: "./src",
    tests: "./test-hardhat",
    cache: "./cache",
    artifacts: "./artifacts",
  },
};
