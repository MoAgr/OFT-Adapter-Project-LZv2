import "dotenv/config";

import { execSync } from "child_process";

async function main() {
  console.log("Running LayerZero standard wiring task using layerzero.config.ts");
  execSync("npx hardhat lz:oapp:wire --oapp-config layerzero.config.ts", { stdio: "inherit" });
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
