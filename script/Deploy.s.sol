// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {Script, console2} from "forge-std/Script.sol";

import {LegacyToken} from "contracts/token/LegacyToken.sol";
import {
    LegacyTokenOFTAdapter
} from "contracts/bridge/LegacyTokenOFTAdapter.sol";
import {LegacyTokenOFT} from "contracts/bridge/LegacyTokenOFT.sol";

contract Deploy is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        address delegate = vm.envAddress("DELEGATE_ADDRESS");
        address sepoliaEndpoint = vm.envAddress("LZ_ENDPOINT_SEPOLIA");
        address baseEndpoint = vm.envAddress("LZ_ENDPOINT_BASE_SEPOLIA");
        address arbitrumEndpoint = vm.envAddress(
            "LZ_ENDPOINT_ARBITRUM_SEPOLIA"
        );
        uint256 initialBridgeCap = vm.envOr(
            "INITIAL_BRIDGE_CAP",
            uint256(2_000_000 ether)
        );

        vm.startBroadcast(deployerPrivateKey);

        LegacyToken legacyToken = new LegacyToken("Legacy Token", "LGT");
        LegacyTokenOFTAdapter adapter = new LegacyTokenOFTAdapter(
            address(legacyToken),
            sepoliaEndpoint,
            delegate,
            initialBridgeCap
        );
        LegacyTokenOFT baseOft = new LegacyTokenOFT(
            "Legacy Token",
            "LGT",
            baseEndpoint,
            delegate
        );
        LegacyTokenOFT arbitrumOft = new LegacyTokenOFT(
            "Legacy Token",
            "LGT",
            arbitrumEndpoint,
            delegate
        );

        vm.stopBroadcast();

        console2.log("LegacyToken deployed:", address(legacyToken));
        console2.log("LegacyTokenOFTAdapter deployed:", address(adapter));
        console2.log("LegacyTokenOFT (Base) deployed:", address(baseOft));
        console2.log(
            "LegacyTokenOFT (Arbitrum) deployed:",
            address(arbitrumOft)
        );
    }
}
