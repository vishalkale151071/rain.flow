import type { HardhatUserConfig } from "hardhat/types";
import "@nomiclabs/hardhat-ethers";
import "@typechain/hardhat";
import "@nomiclabs/hardhat-waffle";


function createLocalhostConfig() {
  const url = "http://localhost:8545";
  const mnemonic =
    "test test test test test test test test test test test junk";
  return {
    accounts: {
      count: 10,
      initialIndex: 0,
      mnemonic,
      path: "m/44'/60'/0'/0",
    },
    url,
  };
}

const config: HardhatUserConfig = {
  networks: {
    hardhat: {
      blockGasLimit: 100000000,
      allowUnlimitedContractSize: true,
    },
    localhost: createLocalhostConfig(),
  },
  defaultNetwork: "localhost",
//   solidity: {
//     compilers: [
//       {
//         version: "0.8.18",
//         settings: {
//           optimizer: {
//             enabled: true,
//             runs: 1000000,
//             details: {
//               peephole: true,
//               inliner: true,
//               jumpdestRemover: true,
//               orderLiterals: true,
//               deduplicate: true,
//               cse: true,
//               constantOptimizer: true,
//             },
//           },
//           evmVersion: "london",
//           // viaIR: true,
//           metadata: {
//             useLiteralContent: true,
//           },
//         },
//       },
//     ],
//   },
};
export default config;