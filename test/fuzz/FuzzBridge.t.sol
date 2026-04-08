// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {
    LegacyTokenOFTAdapter
} from "contracts/bridge/LegacyTokenOFTAdapter.sol";
import {BridgeTestHelper} from "test/helpers/TestHelpers.sol";
import {
    RateLimiter
} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/utils/RateLimiter.sol";

contract FuzzBridgeTest is BridgeTestHelper {
    function setUp() public override {
        super.setUp();

        RateLimiter.RateLimitConfig[]
            memory adapterConfigs = new RateLimiter.RateLimitConfig[](2);
        adapterConfigs[0] = RateLimiter.RateLimitConfig({
            dstEid: BASE_EID,
            limit: 10_000_000 * DECIMALS,
            window: DEFAULT_RATE_WINDOW
        });
        adapterConfigs[1] = RateLimiter.RateLimitConfig({
            dstEid: ARBITRUM_EID,
            limit: 10_000_000 * DECIMALS,
            window: DEFAULT_RATE_WINDOW
        });
        adapter.setRateLimits(adapterConfigs);
    }

    function test_Fuzz_BridgeOut_NeverExceedsCap(uint256 amount) external {
        amount = bound(amount, SHARED_DECIMAL_CONVERSION, INITIAL_CAP * 2);
        uint256 cleaned = _cleanAmount(amount);

        vm.prank(HOLDER_1);
        legacyToken.approve(address(adapter), amount);

        uint256 available = adapter.getAvailableCapacity();
        if (cleaned <= available) {
            adapter.exposedDebit(HOLDER_1, amount, cleaned, BASE_EID);
            assertEq(adapter.getBridgedAmount(), cleaned);
        } else {
            vm.expectRevert(
                abi.encodeWithSelector(
                    LegacyTokenOFTAdapter.BridgeCapExceeded.selector,
                    cleaned,
                    available
                )
            );
            adapter.exposedDebit(HOLDER_1, amount, cleaned, BASE_EID);
        }

        assertLe(adapter.getBridgedAmount(), adapter.getBridgeCap());
    }

    function test_Fuzz_DustAlwaysStripped(uint256 amount) external {
        amount = bound(amount, SHARED_DECIMAL_CONVERSION + 1, INITIAL_CAP);
        uint256 cleaned = _cleanAmount(amount);
        vm.assume(cleaned > 0);

        (uint256 amountSentLD, ) = _debitAdapter(
            HOLDER_1,
            amount,
            cleaned,
            BASE_EID
        );

        assertEq(amountSentLD, cleaned);
        assertEq(adapter.getBridgedAmount(), cleaned);
    }

    function test_Fuzz_SetBridgeCap_BoundaryConditions(
        uint256 newCap
    ) external {
        (uint256 bridged, ) = _debitAdapter(
            HOLDER_1,
            100 * DECIMALS,
            100 * DECIMALS,
            BASE_EID
        );

        if (newCap == 0) {
            vm.expectRevert(
                LegacyTokenOFTAdapter.BridgeCapCannotBeZero.selector
            );
            adapter.setBridgeCap(newCap);
            return;
        }

        if (newCap >= bridged) {
            adapter.setBridgeCap(newCap);
            assertEq(adapter.getBridgeCap(), newCap);
            assertGe(adapter.getBridgeCap(), adapter.getBridgedAmount());
        } else {
            vm.expectRevert(
                abi.encodeWithSelector(
                    LegacyTokenOFTAdapter.BridgeCapBelowCurrentBridged.selector,
                    newCap,
                    bridged
                )
            );
            adapter.setBridgeCap(newCap);
        }
    }

    function test_Fuzz_BridgeInAndOut_BalanceConservation(
        uint256 outAmount,
        uint256 inAmount
    ) external {
        outAmount = bound(
            outAmount,
            SHARED_DECIMAL_CONVERSION,
            300_000 * DECIMALS
        );
        uint256 outCleaned = _cleanAmount(outAmount);
        vm.assume(outCleaned > 0);

        (uint256 outSent, ) = _debitAdapter(
            HOLDER_1,
            outAmount,
            outCleaned,
            BASE_EID
        );

        inAmount = bound(inAmount, 0, outSent);
        uint256 credited = _creditAdapter(HOLDER_1, inAmount, BASE_EID);

        assertEq(legacyToken.balanceOf(address(adapter)), outSent - credited);
        assertEq(adapter.getBridgedAmount(), outSent - credited);
    }
}
