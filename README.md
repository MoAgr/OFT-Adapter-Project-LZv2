# LegacyToken OFT Adapter (LayerZero v2)

A cross-chain token bridge implementation using LayerZero v2 with:

- an adapter-based OFT on Sepolia for an existing legacy ERC20
- native OFT peers on Base Sepolia and Arbitrum Sepolia
- Hardhat deploy/wiring tasks plus Foundry tests

## What this project does

This repository implements a 3-chain mesh:

- Sepolia: `LegacyTokenOFTAdapter` wraps a legacy ERC20 (`LegacyToken` or pre-existing token)
- Base Sepolia: `LegacyTokenOFT`
- Arbitrum Sepolia: `LegacyTokenOFT`

The LayerZero config in `layerzero.config.ts` defines bidirectional pathways between all three chains and enforced executor options for receive flows.

## Repository layout

- `contracts/token/LegacyToken.sol`: local legacy token used for adapter-chain testing/deployment
- `contracts/bridge/LegacyTokenOFTAdapter.sol`: adapter contract for legacy ERC20
- `contracts/bridge/LegacyTokenOFT.sol`: remote OFT implementation
- `contracts/interfaces/ILegacyTokenOFTAdapter.sol`: adapter interface
- `deploy/`: Hardhat deploy scripts
- `layerzero.config.ts`: OApp mesh and wiring config
- `hardhat.config.ts`: network, account, and plugin configuration
- `foundry.toml`: Foundry profile and test settings
- `test/`: unit, fuzz, and invariant suites

## Prerequisites

- Node.js 18+
- npm 9+
- Foundry (`forge`, `cast`, `anvil`)
- Git (with submodule support)

## Setup

1. Clone and initialize submodules:

```bash
git clone <your-repo-url>
cd "OFT Adapter Project (New)"
git submodule update --init --recursive
```

2. Install JS dependencies:

```bash
npm install
```

3. Create environment file:

```bash
cp .env.example .env
```

4. Fill required values in `.env`.

## Environment variables

### Network + signer

- `SEPOLIA_RPC_URL`
- `BASE_SEPOLIA_RPC_URL`
- `ARBITRUM_SEPOLIA_RPC_URL`
- `MNEMONIC` or `PRIVATE_KEY` (at least one is required)
- `DELEGATE_ADDRESS` (optional; defaults to deployer in some flows)

### Token + bridge config

- `INITIAL_BRIDGE_CAP` (optional; defaults to 2,000,000 tokens with 18 decimals)
- `LEGACY_TOKEN_ADDRESS` (optional)

If `LEGACY_TOKEN_ADDRESS` is set on Sepolia, the adapter deploy script points to that token instead of a newly deployed `LegacyToken`.

### Explorer keys

- `ETHERSCAN_API_KEY`
- `BASESCAN_API_KEY`
- `ARBISCAN_API_KEY`

### LayerZero endpoint addresses

- `LZ_ENDPOINT_SEPOLIA`
- `LZ_ENDPOINT_BASE_SEPOLIA`
- `LZ_ENDPOINT_ARBITRUM_SEPOLIA`

## Build and test

Compile with Hardhat:

```bash
npm run compile
```

Run Hardhat tests:

```bash
npm test
```

Run Foundry tests (recommended for this repo):

```bash
forge test -vv
```

Useful focused suites:

```bash
forge test --match-path test/unit/*.t.sol -vv
forge test --match-path test/fuzz/*.t.sol -vv
forge test --match-path test/invariant/*.t.sol -vv
```

## Deployment workflow

This project uses `hardhat-deploy` and LayerZero toolbox tasks.

### 1) Deploy on adapter chain (Sepolia)

Deploy legacy token + adapter:

```bash
npx hardhat lz:deploy --network sepolia --tags LegacyToken,LegacyTokenOFTAdapter
```

### 2) Deploy remote OFTs

Base Sepolia:

```bash
npx hardhat lz:deploy --network base-sepolia --tags LegacyTokenOFT
```

Arbitrum Sepolia:

```bash
npx hardhat lz:deploy --network arbitrum-sepolia --tags LegacyTokenOFT
```

### 3) Inspect generated OApp wiring config

```bash
npm run lz:oapp:config:get
```

### 4) Wire the mesh

```bash
npm run lz:oapp:wire
```

You can also run the helper script:

```bash
npx hardhat run deploy/04_wire_mesh.ts
```

## Common commands

```bash
npm run clean
npm run compile
npm test
npm run lz:deploy
npm run lz:oapp:config:get
npm run lz:oapp:wire
```

## Notes

- `lib/forge-std` is tracked as a git submodule. Always run:

```bash
git submodule update --init --recursive
```

after cloning.

- `hardhat.config.ts` warns if both `MNEMONIC` and `PRIVATE_KEY` are missing; deployment and tx execution require a signer.
- Generated artifacts and local analysis outputs are intentionally gitignored.
