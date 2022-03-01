const HDWalletProvider = require('@truffle/hdwallet-provider');
const privateKeyTest =
  "cf83092b2b6dd847a02a0d039ce51b2c887e9f9d4252b8c09a13dd5c36871fb7";

module.exports = {
  plugins: ["truffle-contract-size"],
  networks: {
    harmony_testnet: {
      provider: () => {
        // use private key
        return new HDWalletProvider({
          //mnemonic,
          providerOrUrl: "https://api.s0.b.hmny.io", // https://api.s0.t.hmny.io for mainnet
          privateKeys: [privateKeyTest],

          //derivationPath: `m/44'/1023'/0'/0/`
        });
      },
      network_id: 1666700000, // 1666600000 for mainnet
      // gas: 2000000, // <--- Twice as much
      // gasPrice: 10000000000,
      networkCheckTimeout: 1000000,
      timeoutBlocks: 200,
    },
    testnetHar: {
      provider: () => {
        if (!privateKeyTest.trim()) {
          throw new Error(
            "Please enter a private key with funds, you can use the default one"
          );
        }
        return new HDWalletProvider({
          privateKeys: [privateKeyTest],
          providerOrUrl: "https://api.s0.b.hmny.io",
        });
      },
      network_id: 1666700000,
    },
  },
  // Configure your compilers
  compilers: {
    solc: {
      version: "^0.7.6", // Fetch exact version from solc-bin (default: truffle's version)
      // docker: true,        // Use "0.5.1" you've installed locally with docker (default: false)
      // settings: {          // See the solidity docs for advice about optimization and evmVersion
      //  optimizer: {
      //    enabled: false,
      //    runs: 200
      //  },
      //  evmVersion: "byzantium"
      // }
      settings: {
        // See the solidity docs for advice about optimization and evmVersion
        optimizer: {
          enabled: true,
          runs: 200,
        },
      },
    },
  },
};

