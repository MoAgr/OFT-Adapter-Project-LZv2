import "dotenv/config";

import assert from "assert";

import { DeployFunction } from "hardhat-deploy/types";

const contractName = "LegacyTokenOFTAdapter";

const deploy: DeployFunction = async (hre) => {
  const { getNamedAccounts, deployments } = hre;

  const { deploy, getOrNull } = deployments;
  const { deployer } = await getNamedAccounts();

  assert(deployer, "Missing named deployer account");

  if (hre.network.config.oftAdapter == null) {
    console.warn("No oftAdapter config on this network, skipping LegacyTokenOFTAdapter deployment");
    return;
  }

  const endpointV2Deployment = await hre.deployments.get("EndpointV2");

  const delegate = process.env.DELEGATE_ADDRESS;
  const initialBridgeCap = process.env.INITIAL_BRIDGE_CAP || hre.ethers.utils.parseEther("2000000").toString();

  const deployedLegacyToken = await getOrNull("LegacyToken");
  const configuredToken = hre.network.config.oftAdapter.tokenAddress;
  const tokenAddress = configuredToken !== "0x0" ? configuredToken : deployedLegacyToken?.address;

  if (!tokenAddress) {
    throw new Error("Missing legacy token address. Set networks.<chain>.oftAdapter.tokenAddress or deploy LegacyToken first.");
  }

  const result = await deploy(contractName, {
    from: deployer,
    args: [tokenAddress, endpointV2Deployment.address, delegate || deployer, initialBridgeCap],
    log: true,
    skipIfAlreadyDeployed: false,
  });

  console.log(`Deployed contract: ${contractName}, network: ${hre.network.name}, address: ${result.address}`);
};

deploy.tags = [contractName];

export default deploy;
