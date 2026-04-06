import "dotenv/config";
import "hardhat-deploy";
import "@nomiclabs/hardhat-ethers";
import "@layerzerolabs/toolbox-hardhat";

import { EndpointId } from "@layerzerolabs/lz-definitions";
import { HardhatUserConfig, HttpNetworkAccountsUserConfig } from "hardhat/types";

import "./type-extensions";

const MNEMONIC = process.env.MNEMONIC;
const PRIVATE_KEY = process.env.PRIVATE_KEY;

const accounts: HttpNetworkAccountsUserConfig | undefined = MNEMONIC
  ? { mnemonic: MNEMONIC }
  : PRIVATE_KEY
    ? [PRIVATE_KEY]
    : undefined;

if (accounts == null) {
  console.warn("Missing MNEMONIC or PRIVATE_KEY; deployments and wiring tx execution will not work.");
}

const config: HardhatUserConfig = {
  paths: {
    cache: "cache/hardhat",
  },
  solidity: {
    version: "0.8.22",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
    },
  },
  networks: {
    sepolia: {
      eid: EndpointId.SEPOLIA_V2_TESTNET,
      url: process.env.SEPOLIA_RPC_URL || "",
      accounts,
      oftAdapter: {
        tokenAddress: process.env.LEGACY_TOKEN_ADDRESS || "0x0",
      },
    },
    "base-sepolia": {
      eid: EndpointId.BASESEP_V2_TESTNET,
      url: process.env.BASE_SEPOLIA_RPC_URL || "",
      accounts,
    },
    "arbitrum-sepolia": {
      eid: EndpointId.ARBSEP_V2_TESTNET,
      url: process.env.ARBITRUM_SEPOLIA_RPC_URL || "",
      accounts,
    },
    hardhat: {
      allowUnlimitedContractSize: true,
    },
  },
  namedAccounts: {
    deployer: {
      default: 0,
    },
  },
};

export default config;
