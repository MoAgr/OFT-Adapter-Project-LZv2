import "dotenv/config";

import assert from "assert";

import { DeployFunction } from "hardhat-deploy/types";

const contractName = "LegacyTokenOFT";

const deploy: DeployFunction = async (hre) => {
  const { getNamedAccounts, deployments } = hre;

  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  assert(deployer, "Missing named deployer account");

  // Remote OFTs should deploy on non-adapter chains.
  if (hre.network.config.oftAdapter != null) {
    console.warn("Detected oftAdapter config on this network, skipping LegacyTokenOFT deployment");
    return;
  }

  const endpointV2Deployment = await hre.deployments.get("EndpointV2");
  const delegate = process.env.DELEGATE_ADDRESS || deployer;

  const result = await deploy(contractName, {
    from: deployer,
    args: ["Legacy Token", "LGT", endpointV2Deployment.address, delegate],
    log: true,
    skipIfAlreadyDeployed: false,
  });

  console.log(`Deployed contract: ${contractName}, network: ${hre.network.name}, address: ${result.address}`);
};

deploy.tags = [contractName];

export default deploy;
