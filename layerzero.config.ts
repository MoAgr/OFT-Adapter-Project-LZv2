import "dotenv/config";
import { EndpointId } from "@layerzerolabs/lz-definitions";
import { ExecutorOptionType } from "@layerzerolabs/lz-v2-utilities";
import { TwoWayConfig, generateConnectionsConfig } from "@layerzerolabs/metadata-tools";
import { OAppEnforcedOption } from "@layerzerolabs/toolbox-hardhat";

import type { OmniPointHardhat } from "@layerzerolabs/toolbox-hardhat";

const sepoliaAdapter: OmniPointHardhat = {
  eid: EndpointId.SEPOLIA_V2_TESTNET,
  contractName: "LegacyTokenOFTAdapter",
};

const baseOft: OmniPointHardhat = {
  eid: EndpointId.BASESEP_V2_TESTNET,
  contractName: "LegacyTokenOFT",
};

const arbitrumOft: OmniPointHardhat = {
  eid: EndpointId.ARBSEP_V2_TESTNET,
  contractName: "LegacyTokenOFT",
};

const EVM_ENFORCED_OPTIONS: OAppEnforcedOption[] = [
  {
    msgType: 1,
    optionType: ExecutorOptionType.LZ_RECEIVE,
    gas: 200000, //about 30-40% headroom after worst _credit path snapshot
    value: 0,
  },
];

// Full 3-chain mesh as three bidirectional pathways:
// Sepolia <-> Base
// Sepolia <-> Arbitrum
// Base <-> Arbitrum
const pathways: TwoWayConfig[] = [
  [
    sepoliaAdapter,
    baseOft,
    [["LayerZero Labs"], []],
    [15, 15],
    [EVM_ENFORCED_OPTIONS, EVM_ENFORCED_OPTIONS],
  ],
  [
    sepoliaAdapter,
    arbitrumOft,
    [["LayerZero Labs"], []],
    [15, 15],
    [EVM_ENFORCED_OPTIONS, EVM_ENFORCED_OPTIONS],
  ],
  [
    baseOft,
    arbitrumOft,
    [["LayerZero Labs"], []],
    [15, 15],
    [EVM_ENFORCED_OPTIONS, EVM_ENFORCED_OPTIONS],
  ],
];

export default async function () {
  const connections = await generateConnectionsConfig(pathways);
  return {
    contracts: [
      {
        contract: sepoliaAdapter,
      },
      {
        contract: baseOft,
      },
      {
        contract: arbitrumOft,
      },
    ],
    connections,
  };
}
