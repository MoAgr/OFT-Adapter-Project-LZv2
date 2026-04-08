// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {
    RateLimiter
} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/utils/RateLimiter.sol";

import {LegacyTokenOFT} from "contracts/bridge/LegacyTokenOFT.sol";

import {BridgeTestHelper} from "test/helpers/TestHelpers.sol";

contract LegacyTokenOFTTest is BridgeTestHelper {
    function test_Constructor_SetsCorrectState() external view {
        assertEq(oftBase.name(), "Legacy Token");
        assertEq(oftBase.symbol(), "LGT");
        assertEq(oftBase.sharedDecimals(), 6);
        assertEq(oftBase.totalSupply(), 0);
        assertEq(oftBase.owner(), address(this));
        assertEq(_endpointDelegate(address(oftBase)), delegate);
    }

    function test_Constructor_RevertIf_EndpointZero() external {
        vm.expectRevert(LegacyTokenOFT.ZeroAddress.selector);
        new LegacyTokenOFT("Legacy Token", "LGT", address(0), delegate);
    }

    function test_Constructor_RevertIf_DelegateZero() external {
        vm.expectRevert(LegacyTokenOFT.ZeroAddress.selector);
        new LegacyTokenOFT(
            "Legacy Token",
            "LGT",
            address(endpoint),
            address(0)
        );
    }

    function test_MintOnReceive() external {
        uint256 amount = 120 * DECIMALS;

        uint256 amountReceived = _creditBase(HOLDER_2, amount, SEPOLIA_EID);

        assertEq(oftBase.balanceOf(HOLDER_2), amountReceived);
        assertEq(oftBase.totalSupply(), amountReceived);
    }

    function test_BurnOnSend() external {
        uint256 inboundAmount = 90 * DECIMALS;

        uint256 inAmountReceived = _creditBase(
            HOLDER_2,
            inboundAmount,
            SEPOLIA_EID
        );

        uint256 supplyBeforeBurn = oftBase.totalSupply();

        (uint256 amountSentLD, ) = _debitBase(
            HOLDER_2,
            40 * DECIMALS,
            40 * DECIMALS,
            SEPOLIA_EID
        );

        assertEq(oftBase.balanceOf(HOLDER_2), inAmountReceived - amountSentLD);
        assertEq(oftBase.totalSupply(), supplyBeforeBurn - amountSentLD);
    }

    function test_BridgeOut_RevertIf_Paused() external {
        uint256 amount = 60 * DECIMALS;

        _creditBase(HOLDER_2, amount, SEPOLIA_EID);

        oftBase.pause();

        vm.expectRevert(LegacyTokenOFT.ContractPaused.selector);
        _debitBase(HOLDER_2, amount, amount, SEPOLIA_EID);
    }

    function test_BridgeIn_RevertIf_Paused() external {
        oftBase.pause();

        vm.expectRevert(LegacyTokenOFT.ContractPaused.selector);
        _creditBase(HOLDER_2, 1 * DECIMALS, SEPOLIA_EID);
    }

    function test_SharedDecimals_Is6() external view {
        assertEq(oftBase.sharedDecimals(), 6);
        assertEq(oftArbitrum.sharedDecimals(), 6);
    }

    function test_SetRateLimits_OnlyOwner() external {
        RateLimiter.RateLimitConfig[]
            memory rateLimitConfigs = new RateLimiter.RateLimitConfig[](1);
        rateLimitConfigs[0] = RateLimiter.RateLimitConfig({
            dstEid: SEPOLIA_EID,
            limit: DECIMALS,
            window: 60
        });

        vm.prank(HOLDER_1);
        vm.expectRevert("Ownable: caller is not the owner");
        oftBase.setRateLimits(rateLimitConfigs);
    }
}
