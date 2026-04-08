// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {StdInvariant} from "forge-std/StdInvariant.sol";
import {Test} from "forge-std/Test.sol";

import {LegacyTokenOFTAdapterHarness} from "test/helpers/TestHelpers.sol";
import {LegacyToken} from "contracts/token/LegacyToken.sol";
import {BridgeTestHelper} from "test/helpers/TestHelpers.sol";

contract Handler is Test {
    LegacyTokenOFTAdapterHarness internal immutable adapter;
    LegacyToken internal immutable token;

    address internal immutable holder;
    uint32 internal immutable baseEid;

    uint256 internal immutable conversion;

    constructor(
        LegacyTokenOFTAdapterHarness adapter_,
        LegacyToken token_,
        address holder_,
        uint32 baseEid_,
        uint256 conversion_
    ) {
        adapter = adapter_;
        token = token_;
        holder = holder_;
        baseEid = baseEid_;
        conversion = conversion_;
    }

    function bridgeOut(uint256 amount) external {
        uint256 holderBalance = token.balanceOf(holder);
        if (holderBalance == 0) return;

        amount = bound(amount, conversion, holderBalance);
        uint256 cleaned = amount - (amount % conversion);
        if (cleaned == 0) return;

        vm.prank(holder);
        token.approve(address(adapter), amount);

        try adapter.exposedDebit(holder, amount, cleaned, baseEid) {} catch {}
    }

    function bridgeIn(uint256 amount) external {
        uint256 bridged = adapter.getBridgedAmount();
        if (bridged == 0) return;

        amount = bound(amount, 0, bridged);

        try adapter.exposedCredit(holder, amount, baseEid) {} catch {}
    }

    function setBridgeCap(uint256 newCap) external {
        try adapter.setBridgeCap(newCap) {} catch {}
    }

    function pause() external {
        try adapter.pause() {} catch {}
    }

    function unpause() external {
        try adapter.unpause() {} catch {}
    }
}

contract InvariantBridgeTest is StdInvariant, BridgeTestHelper {
    Handler internal handler;

    function setUp() public override {
        super.setUp();

        handler = new Handler(
            adapter,
            legacyToken,
            HOLDER_1,
            BASE_EID,
            SHARED_DECIMAL_CONVERSION
        );
        adapter.transferOwnership(address(handler));

        targetContract(address(handler));
    }

    function invariant_BridgedAmountNeverExceedsCap() external view {
        assertLe(adapter.getBridgedAmount(), adapter.getBridgeCap());
    }

    function invariant_AdapterBalanceCoversBridgedAmount() external view {
        assertGe(
            legacyToken.balanceOf(address(adapter)),
            adapter.getBridgedAmount()
        );
    }

    function invariant_TotalSupplyUnchanged() external view {
        assertEq(legacyToken.totalSupply(), 10_000_000 * DECIMALS);
    }

    function invariant_SharedDecimalsNeverChanges() external view {
        assertEq(adapter.sharedDecimals(), 6);
        assertEq(oftBase.sharedDecimals(), 6);
        assertEq(oftArbitrum.sharedDecimals(), 6);
    }
}
