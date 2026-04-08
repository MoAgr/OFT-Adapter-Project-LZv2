// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {
    RateLimiter
} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/utils/RateLimiter.sol";

import {LegacyToken} from "contracts/token/LegacyToken.sol";
import {
    LegacyTokenOFTAdapter
} from "contracts/bridge/LegacyTokenOFTAdapter.sol";
import {
    ILegacyTokenOFTAdapter
} from "contracts/interfaces/ILegacyTokenOFTAdapter.sol";

import {BridgeTestHelper} from "test/helpers/TestHelpers.sol";

contract LegacyTokenOFTAdapterTest is BridgeTestHelper {
    function test_Constructor_SetsCorrectState() external view {
        assertEq(adapter.getBridgeCap(), INITIAL_CAP);
        assertEq(adapter.token(), address(legacyToken));
        assertEq(adapter.sharedDecimals(), 6);
        assertEq(adapter.owner(), address(this));
        assertEq(_endpointDelegate(address(adapter)), delegate);
    }

    function test_Constructor_RevertIf_TokenZero() external {
        vm.expectRevert(LegacyTokenOFTAdapter.ZeroAddress.selector);
        new LegacyTokenOFTAdapter(
            address(0),
            address(endpoint),
            delegate,
            INITIAL_CAP
        );
    }

    function test_Constructor_RevertIf_EndpointZero() external {
        vm.expectRevert(LegacyTokenOFTAdapter.ZeroAddress.selector);
        new LegacyTokenOFTAdapter(
            address(legacyToken),
            address(0),
            delegate,
            INITIAL_CAP
        );
    }

    function test_Constructor_RevertIf_DelegateZero() external {
        vm.expectRevert(LegacyTokenOFTAdapter.ZeroAddress.selector);
        new LegacyTokenOFTAdapter(
            address(legacyToken),
            address(endpoint),
            address(0),
            INITIAL_CAP
        );
    }

    function test_Constructor_RevertIf_InitialCapZero() external {
        vm.expectRevert(LegacyTokenOFTAdapter.BridgeCapCannotBeZero.selector);
        new LegacyTokenOFTAdapter(
            address(legacyToken),
            address(endpoint),
            delegate,
            0
        );
    }

    function test_SetBridgeCap_Success() external {
        uint256 newCap = 1_750_000 * DECIMALS;

        vm.expectEmit(true, true, true, true);
        emit ILegacyTokenOFTAdapter.BridgeCapUpdated(INITIAL_CAP, newCap);

        adapter.setBridgeCap(newCap);

        assertEq(adapter.getBridgeCap(), newCap);
    }

    function test_SetBridgeCap_RevertIf_Zero() external {
        vm.expectRevert(LegacyTokenOFTAdapter.BridgeCapCannotBeZero.selector);
        adapter.setBridgeCap(0);
    }

    function test_SetBridgeCap_RevertIf_BelowCurrentBridged() external {
        uint256 outAmount = 100 * DECIMALS;
        (uint256 amountSentLD, ) = _debitAdapter(
            HOLDER_1,
            outAmount,
            outAmount,
            BASE_EID
        );

        vm.expectRevert(
            abi.encodeWithSelector(
                LegacyTokenOFTAdapter.BridgeCapBelowCurrentBridged.selector,
                amountSentLD - 1,
                amountSentLD
            )
        );
        adapter.setBridgeCap(amountSentLD - 1);
    }

    function test_SetBridgeCap_RevertIf_NotOwner() external {
        vm.prank(HOLDER_1);
        vm.expectRevert("Ownable: caller is not the owner");
        adapter.setBridgeCap(INITIAL_CAP + (1 * DECIMALS));
    }

    function test_BridgeOut_Success() external {
        uint256 amount = 100 * DECIMALS;
        uint256 senderBefore = legacyToken.balanceOf(HOLDER_1);
        uint256 adapterBefore = legacyToken.balanceOf(address(adapter));

        (uint256 amountSentLD, uint256 amountReceivedLD) = _debitAdapter(
            HOLDER_1,
            amount,
            amount,
            BASE_EID
        );

        assertEq(adapter.getBridgedAmount(), amountSentLD);
        assertEq(legacyToken.balanceOf(HOLDER_1), senderBefore - amountSentLD);
        assertEq(
            legacyToken.balanceOf(address(adapter)),
            adapterBefore + amountSentLD
        );
        assertEq(amountReceivedLD, amountSentLD);
    }

    function test_BridgeOut_RevertIf_ExceedsCap() external {
        uint256 tooMuch = INITIAL_CAP + DECIMALS;

        vm.prank(HOLDER_1);
        legacyToken.approve(address(adapter), tooMuch);

        vm.expectRevert(
            abi.encodeWithSelector(
                LegacyTokenOFTAdapter.BridgeCapExceeded.selector,
                tooMuch,
                adapter.getAvailableCapacity()
            )
        );
        adapter.exposedDebit(HOLDER_1, tooMuch, tooMuch, BASE_EID);
    }

    function test_BridgeOut_RevertIf_Paused() external {
        adapter.pause();

        uint256 amount = 10 * DECIMALS;
        vm.prank(HOLDER_1);
        legacyToken.approve(address(adapter), amount);

        vm.expectRevert(LegacyTokenOFTAdapter.ContractPaused.selector);
        adapter.exposedDebit(HOLDER_1, amount, amount, BASE_EID);
    }

    function test_BridgeIn_Success() external {
        uint256 outAmount = 75 * DECIMALS;
        (uint256 outAmountSent, ) = _debitAdapter(
            HOLDER_1,
            outAmount,
            outAmount,
            BASE_EID
        );

        uint256 inAmount = 40 * DECIMALS;
        uint256 received = _creditAdapter(HOLDER_1, inAmount, BASE_EID);

        assertEq(adapter.getBridgedAmount(), outAmountSent - received);
        assertEq(
            legacyToken.balanceOf(HOLDER_1),
            (4_000_000 * DECIMALS) - outAmountSent + received
        );
    }

    function test_BridgeIn_Success_WhenSrcEidZero() external {
        uint256 outAmount = 50 * DECIMALS;
        (uint256 outAmountSent, ) = _debitAdapter(
            HOLDER_1,
            outAmount,
            outAmount,
            BASE_EID
        );

        uint256 inAmount = 20 * DECIMALS;
        uint256 received = _creditAdapter(HOLDER_1, inAmount, 0);

        assertEq(received, inAmount);
        assertEq(adapter.getBridgedAmount(), outAmountSent - received);
    }

    function test_BridgeIn_RevertIf_Paused() external {
        adapter.pause();

        vm.expectRevert(LegacyTokenOFTAdapter.ContractPaused.selector);
        _creditAdapter(HOLDER_1, 1 * DECIMALS, BASE_EID);
    }

    function test_Pause_OnlyOwner() external {
        vm.prank(HOLDER_1);
        vm.expectRevert("Ownable: caller is not the owner");
        adapter.pause();
    }

    function test_Unpause_OnlyOwner() external {
        adapter.pause();

        vm.prank(HOLDER_1);
        vm.expectRevert("Ownable: caller is not the owner");
        adapter.unpause();
    }

    function test_RecoverStuckTokens_Success() external {
        LegacyToken randomToken = new LegacyToken("Random", "RND");
        uint256 amount = 10 * DECIMALS;
        uint256 holder2Before = randomToken.balanceOf(HOLDER_2);

        vm.prank(HOLDER_1);
        bool sent = randomToken.transfer(address(adapter), amount);
        assertTrue(sent);

        vm.expectEmit(true, true, true, true);
        emit ILegacyTokenOFTAdapter.TokensRecovered(
            address(randomToken),
            HOLDER_2,
            amount
        );

        adapter.recoverStuckTokens(address(randomToken), HOLDER_2, amount);

        assertEq(randomToken.balanceOf(HOLDER_2), holder2Before + amount);
    }

    function test_RecoverStuckTokens_RevertIf_BridgeToken() external {
        vm.expectRevert(
            LegacyTokenOFTAdapter.CannotRecoverBridgeToken.selector
        );
        adapter.recoverStuckTokens(address(legacyToken), HOLDER_2, 1);
    }

    function test_RecoverStuckTokens_RevertIf_ToZero() external {
        LegacyToken randomToken = new LegacyToken("Random", "RND");

        vm.expectRevert(LegacyTokenOFTAdapter.ZeroAddress.selector);
        adapter.recoverStuckTokens(address(randomToken), address(0), 1);
    }

    function test_RecoverStuckTokens_RevertIf_AmountZero() external {
        LegacyToken randomToken = new LegacyToken("Random", "RND");

        vm.expectRevert(LegacyTokenOFTAdapter.ZeroAmount.selector);
        adapter.recoverStuckTokens(address(randomToken), HOLDER_2, 0);
    }

    function test_GetAvailableCapacity_CorrectMath() external {
        uint256 amount = 60 * DECIMALS;
        (uint256 amountSentLD, ) = _debitAdapter(
            HOLDER_1,
            amount,
            amount,
            BASE_EID
        );

        assertEq(adapter.getAvailableCapacity(), INITIAL_CAP - amountSentLD);
    }

    function test_SharedDecimals_Is6() external view {
        assertEq(adapter.sharedDecimals(), 6);
    }

    function test_DustRemoval() external {
        uint256 amountWithDust = 1_000_000_000_000_100;
        uint256 cleaned = _cleanAmount(amountWithDust);

        (uint256 amountSentLD, ) = _debitAdapter(
            HOLDER_1,
            amountWithDust,
            cleaned,
            BASE_EID
        );

        assertEq(amountSentLD, cleaned);
        assertEq(adapter.getBridgedAmount(), cleaned);
    }

    function test_SetRateLimits_OnlyOwner() external {
        RateLimiter.RateLimitConfig[]
            memory rateLimitConfigs = new RateLimiter.RateLimitConfig[](1);
        rateLimitConfigs[0] = RateLimiter.RateLimitConfig({
            dstEid: BASE_EID,
            limit: DECIMALS,
            window: 60
        });

        vm.prank(HOLDER_1);
        vm.expectRevert("Ownable: caller is not the owner");
        adapter.setRateLimits(rateLimitConfigs);
    }
}
