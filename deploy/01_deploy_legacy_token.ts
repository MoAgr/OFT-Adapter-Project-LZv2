import "dotenv/config";

import assert from "assert";

import { DeployFunction } from "hardhat-deploy/types";

const contractName = "LegacyToken";

const deploy: DeployFunction = async (hre) => {
  const { getNamedAccounts, deployments } = hre;

  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  assert(deployer, "Missing named deployer account");

  // Only deploy the underlying legacy token on the adapter chain.
  if (hre.network.config.oftAdapter == null) {
    console.warn("No oftAdapter config on this network, skipping LegacyToken deployment");
    return;
  }

  console.log(`Deployer: ${deployer}`);
  console.log(`Network: ${hre.network.name}`);

  const result = await deploy(contractName, {
    from: deployer,
    args: ["Legacy Token", "LGT"],
    log: true,
    skipIfAlreadyDeployed: false,
  });

  console.log(`Deployed contract: ${contractName}, network: ${hre.network.name}, address: ${result.address}`);
};

deploy.tags = [contractName];

export default deploy;
