// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {Test} from "forge-std/Test.sol";
import {
    RateLimiter
} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/utils/RateLimiter.sol";

import {LegacyToken} from "contracts/token/LegacyToken.sol";
import {
    LegacyTokenOFTAdapter
} from "contracts/bridge/LegacyTokenOFTAdapter.sol";
import {LegacyTokenOFT} from "contracts/bridge/LegacyTokenOFT.sol";

contract MockLzEndpoint {
    mapping(address oapp => address delegate) public delegates;

    function setDelegate(address _delegate) external {
        delegates[msg.sender] = _delegate;
    }
}

contract LegacyTokenOFTAdapterHarness is LegacyTokenOFTAdapter {
    constructor(
        address token_,
        address lzEndpoint_,
        address delegate_,
        uint256 initialCap_
    ) LegacyTokenOFTAdapter(token_, lzEndpoint_, delegate_, initialCap_) {}

    function exposedDebit(
        address from,
        uint256 amountLD,
        uint256 minAmountLD,
        uint32 dstEid
    ) external returns (uint256 amountSentLD, uint256 amountReceivedLD) {
        return _debit(from, amountLD, minAmountLD, dstEid);
    }

    function exposedCredit(
        address to,
        uint256 amountLD,
        uint32 srcEid
    ) external returns (uint256 amountReceivedLD) {
        return _credit(to, amountLD, srcEid);
    }
}

contract LegacyTokenOFTHarness is LegacyTokenOFT {
    constructor(
        string memory name_,
        string memory symbol_,
        address lzEndpoint_,
        address delegate_
    ) LegacyTokenOFT(name_, symbol_, lzEndpoint_, delegate_) {}

    function exposedDebit(
        address from,
        uint256 amountLD,
        uint256 minAmountLD,
        uint32 dstEid
    ) external returns (uint256 amountSentLD, uint256 amountReceivedLD) {
        return _debit(from, amountLD, minAmountLD, dstEid);
    }

    function exposedCredit(
        address to,
        uint256 amountLD,
        uint32 srcEid
    ) external returns (uint256 amountReceivedLD) {
        return _credit(to, amountLD, srcEid);
    }

    function mintForTest(address to, uint256 amountLD) external {
        _credit(to, amountLD, 0);
    }
}

abstract contract BridgeTestHelper is Test {
    uint32 internal constant SEPOLIA_EID = 30101;
    uint32 internal constant BASE_EID = 40245;
    uint32 internal constant ARBITRUM_EID = 40231;

    uint256 internal constant DECIMALS = 1e18;
    uint256 internal constant SHARED_DECIMAL_CONVERSION = 1e12;
    uint256 internal constant INITIAL_CAP = 2_000_000 * DECIMALS;
    uint256 internal constant DEFAULT_RATE_LIMIT = 500_000 * DECIMALS;
    uint256 internal constant DEFAULT_RATE_WINDOW = 3600;

    address internal constant HOLDER_1 =
        0x70997970C51812dc3A010C7d01b50e0d17dc79C8;
    address internal constant HOLDER_2 =
        0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC;
    address internal constant HOLDER_3 =
        0x90F79bf6EB2c4f870365E785982E1f101E93b906;

    MockLzEndpoint internal endpoint;
    LegacyToken internal legacyToken;
    LegacyTokenOFTAdapterHarness internal adapter;
    LegacyTokenOFTHarness internal oftBase;
    LegacyTokenOFTHarness internal oftArbitrum;

    address internal delegate;

    function setUp() public virtual {
        endpoint = new MockLzEndpoint();
        delegate = makeAddr("delegate");

        legacyToken = new LegacyToken("Legacy Token", "LGT");
        adapter = new LegacyTokenOFTAdapterHarness(
            address(legacyToken),
            address(endpoint),
            delegate,
            INITIAL_CAP
        );
        oftBase = new LegacyTokenOFTHarness(
            "Legacy Token",
            "LGT",
            address(endpoint),
            delegate
        );
        oftArbitrum = new LegacyTokenOFTHarness(
            "Legacy Token",
            "LGT",
            address(endpoint),
            delegate
        );

        _configureRateLimits();
    }

    function _configureRateLimits() internal {
        RateLimiter.RateLimitConfig[]
            memory adapterConfigs = new RateLimiter.RateLimitConfig[](2);
        adapterConfigs[0] = RateLimiter.RateLimitConfig({
            dstEid: BASE_EID,
            limit: DEFAULT_RATE_LIMIT,
            window: DEFAULT_RATE_WINDOW
        });
        adapterConfigs[1] = RateLimiter.RateLimitConfig({
            dstEid: ARBITRUM_EID,
            limit: DEFAULT_RATE_LIMIT,
            window: DEFAULT_RATE_WINDOW
        });
        adapter.setRateLimits(adapterConfigs);

        RateLimiter.RateLimitConfig[]
            memory baseConfigs = new RateLimiter.RateLimitConfig[](2);
        baseConfigs[0] = RateLimiter.RateLimitConfig({
            dstEid: SEPOLIA_EID,
            limit: DEFAULT_RATE_LIMIT,
            window: DEFAULT_RATE_WINDOW
        });
        baseConfigs[1] = RateLimiter.RateLimitConfig({
            dstEid: ARBITRUM_EID,
            limit: DEFAULT_RATE_LIMIT,
            window: DEFAULT_RATE_WINDOW
        });
        oftBase.setRateLimits(baseConfigs);

        RateLimiter.RateLimitConfig[]
            memory arbConfigs = new RateLimiter.RateLimitConfig[](2);
        arbConfigs[0] = RateLimiter.RateLimitConfig({
            dstEid: SEPOLIA_EID,
            limit: DEFAULT_RATE_LIMIT,
            window: DEFAULT_RATE_WINDOW
        });
        arbConfigs[1] = RateLimiter.RateLimitConfig({
            dstEid: BASE_EID,
            limit: DEFAULT_RATE_LIMIT,
            window: DEFAULT_RATE_WINDOW
        });
        oftArbitrum.setRateLimits(arbConfigs);
    }

    function _debitAdapter(
        address from,
        uint256 amountLD,
        uint256 minAmountLD,
        uint32 dstEid
    ) internal returns (uint256 amountSentLD, uint256 amountReceivedLD) {
        vm.prank(from);
        legacyToken.approve(address(adapter), amountLD);
        return adapter.exposedDebit(from, amountLD, minAmountLD, dstEid);
    }

    function _creditAdapter(
        address to,
        uint256 amountLD,
        uint32 srcEid
    ) internal returns (uint256 amountReceivedLD) {
        return adapter.exposedCredit(to, amountLD, srcEid);
    }

    function _debitBase(
        address from,
        uint256 amountLD,
        uint256 minAmountLD,
        uint32 dstEid
    ) internal returns (uint256 amountSentLD, uint256 amountReceivedLD) {
        return oftBase.exposedDebit(from, amountLD, minAmountLD, dstEid);
    }

    function _creditBase(
        address to,
        uint256 amountLD,
        uint32 srcEid
    ) internal returns (uint256 amountReceivedLD) {
        return oftBase.exposedCredit(to, amountLD, srcEid);
    }

    function _cleanAmount(uint256 amountLD) internal pure returns (uint256) {
        return amountLD - (amountLD % SHARED_DECIMAL_CONVERSION);
    }

    function _endpointDelegate(address oapp) internal view returns (address) {
        return endpoint.delegates(oapp);
    }
}
