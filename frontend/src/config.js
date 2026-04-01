// Sepolia deployed contract addresses
export const ADDRESSES = {
  factory: "0x6e7455DD574065cBC329A080ab10a4A2cdDF3871",
  router: "0x48E134c431ef850cAE51F10800c1F7884c971256",
  tokens: {
    WETH: {
      address: "0x767a1c012548dCAD946Df72125A2E8b7797A2CC9",
      symbol: "WETH",
      name: "Wrapped ETH",
      decimals: 18,
    },
    USDC: {
      address: "0x33bF0eBf6b05eA74514eC9482Fa816f0e1999b08",
      symbol: "USDC",
      name: "USD Coin",
      decimals: 18,
    },
    DAI: {
      address: "0x6dFA61F2b1e735D43A81eEDECafdd4Acd3c6817c",
      symbol: "DAI",
      name: "DAI Stablecoin",
      decimals: 18,
    },
  },
};

export const CHAIN_ID = 11155111; // Sepolia
export const CHAIN_NAME = "Sepolia";
export const EXPLORER_URL = "https://sepolia.etherscan.io";