// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {
    RateLimiter
} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/utils/RateLimiter.sol";

interface ILegacyTokenOFTAdapter {
    event BridgeCapUpdated(uint256 oldCap, uint256 newCap);
    event TokensRecovered(
        address indexed token,
        address indexed to,
        uint256 amount
    );

    function setBridgeCap(uint256 newCap) external;

    function getBridgeCap() external view returns (uint256);

    function getBridgedAmount() external view returns (uint256);

    function getAvailableCapacity() external view returns (uint256);

    function pause() external;

    function unpause() external;

    function recoverStuckTokens(
        address token,
        address to,
        uint256 amount
    ) external;

    function setRateLimits(
        RateLimiter.RateLimitConfig[] calldata rateLimitConfigs
    ) external;
}
