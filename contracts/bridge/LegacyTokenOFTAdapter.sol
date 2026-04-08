// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {OFTAdapter} from "@layerzerolabs/oft-evm/contracts/OFTAdapter.sol";
import {
    RateLimiter
} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/utils/RateLimiter.sol";
import {Pausable} from "@openzeppelin/contracts/security/Pausable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {
    SafeERC20
} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {ILegacyTokenOFTAdapter} from "../interfaces/ILegacyTokenOFTAdapter.sol";

/// @notice Sepolia lockbox adapter for LegacyToken; this is the only adapter in the mesh and the sole canonical lockbox.
/// @dev Enforces bridge cap, rate limiting, and pause controls while preserving supply conservation across lock/mint and burn/unlock flows.
contract LegacyTokenOFTAdapter is
    OFTAdapter,
    RateLimiter,
    Pausable,
    ILegacyTokenOFTAdapter
{
    using SafeERC20 for IERC20;

    /// @notice Maximum amount of LGT (18 decimals) that can be locked in this adapter.
    /// @dev Risk control to cap lockbox exposure.
    uint256 public bridgeCap;

    /// @notice Net amount currently bridged out and locked by this adapter.
    /// @dev Increased on outbound debit and decreased on inbound credit.
    /// @dev uint256 is used to match ERC20 18-decimal amount math and OFT/RateLimiter amount types, avoiding casts and preserving full-range accounting.
    uint256 public bridgedAmount;

    error BridgeCapExceeded(uint256 requested, uint256 available);
    error BridgeCapCannotBeZero();
    error BridgeCapBelowCurrentBridged(uint256 newCap, uint256 currentBridged);
    error ZeroAddress();
    error ZeroAmount();
    error CannotRecoverBridgeToken();
    error ContractPaused();

    /// @notice Deploys the adapter and configures the initial bridge cap and delegate.
    /// @dev Owner is set through OFTAdapter/OApp constructor path and delegate is configured in-constructor to avoid an unsecured gap.
    /// @param token_ Legacy token address on Sepolia.
    /// @param lzEndpoint_ LayerZero endpoint for Sepolia.
    /// @param delegate_ Delegate allowed to manage emergency LayerZero config.
    /// @param initialCap_ Initial bridge cap in local token decimals.
    constructor(
        address token_,
        address lzEndpoint_,
        address delegate_,
        uint256 initialCap_
    )
        OFTAdapter(
            _requireNonZero(token_),
            _requireNonZero(lzEndpoint_),
            msg.sender
        )
    {
        if (delegate_ == address(0)) revert ZeroAddress();
        if (initialCap_ == 0) revert BridgeCapCannotBeZero();

        setDelegate(delegate_);
        bridgeCap = initialCap_;

        emit BridgeCapUpdated(0, initialCap_);
    }

    /// @notice Updates the maximum bridgeable locked amount.
    /// @param newCap New bridge cap in local token decimals.
    function setBridgeCap(uint256 newCap) external onlyOwner {
        if (newCap == 0) revert BridgeCapCannotBeZero();
        if (newCap < bridgedAmount)
            revert BridgeCapBelowCurrentBridged(newCap, bridgedAmount);

        uint256 oldCap = bridgeCap;
        bridgeCap = newCap;

        emit BridgeCapUpdated(oldCap, newCap);
    }

    /// @notice Returns the configured bridge cap.
    /// @return Current cap value in local decimals.
    function getBridgeCap() external view returns (uint256) {
        return bridgeCap;
    }

    /// @notice Returns the amount currently bridged out and locked.
    /// @return Current bridged amount in local decimals.
    function getBridgedAmount() external view returns (uint256) {
        return bridgedAmount;
    }

    /// @notice Returns remaining bridge capacity.
    /// @return Available amount that can still be bridged out.
    function getAvailableCapacity() external view returns (uint256) {
        return bridgeCap - bridgedAmount;
    }

    /// @notice Pauses bridge debit/credit execution.
    function pause() external onlyOwner {
        _pause();
    }

    /// @notice Unpauses bridge debit/credit execution.
    function unpause() external onlyOwner {
        _unpause();
    }

    /// @notice Recovers non-bridge tokens accidentally sent to this contract.
    /// @param token_ Token address to recover.
    /// @param to Recipient of recovered tokens.
    /// @param amount Amount to recover.
    function recoverStuckTokens(
        address token_,
        address to,
        uint256 amount
    ) external onlyOwner {
        if (to == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();
        if (token_ == token()) revert CannotRecoverBridgeToken();

        // slither-disable-next-line arbitrary-send-erc20,reentrancy-events
        IERC20(token_).safeTransfer(to, amount);
        emit TokensRecovered(token_, to, amount);
    }

    /// @notice Sets per-destination rate limits for outbound sends.
    /// @dev Each config entry sets destination eid, token limit, and window size in seconds.
    /// @param rateLimitConfigs Array of destination rate limit configurations.
    function setRateLimits(
        RateLimiter.RateLimitConfig[] calldata rateLimitConfigs
    ) external onlyOwner {
        _setRateLimits(rateLimitConfigs);
    }

    /// @notice Debits tokens on outbound sends by locking cleaned amounts after dust removal.
    /// @param _from Sender address on this chain.
    /// @param _amountLD Requested local-decimal amount.
    /// @param _minAmountLD Minimum acceptable amount after normalization.
    /// @param _dstEid Destination endpoint ID.
    /// @return amountSentLD Cleaned local-decimal amount locked on source.
    /// @return amountReceivedLD Amount represented for destination credit path.
    function _debit(
        address _from,
        uint256 _amountLD,
        uint256 _minAmountLD,
        uint32 _dstEid
    )
        internal
        virtual
        override
        returns (uint256 amountSentLD, uint256 amountReceivedLD)
    {
        if (paused()) revert ContractPaused();

        (amountSentLD, amountReceivedLD) = _debitView(
            _amountLD,
            _minAmountLD,
            _dstEid
        );

        uint256 available = bridgeCap - bridgedAmount;
        if (amountSentLD > available)
            revert BridgeCapExceeded(amountSentLD, available);

        _checkAndUpdateRateLimit(_dstEid, amountSentLD);

        bridgedAmount += amountSentLD;

        // slither-disable-next-line reentrancy-no-eth
        IERC20(token()).safeTransferFrom(_from, address(this), amountSentLD);
    }

    /// @notice Credits tokens on inbound receive path by unlocking from adapter reserves.
    /// @param _to Receiver address on this chain.
    /// @param _amountLD Local-decimal amount to release.
    /// @param _srcEid Source endpoint ID.
    /// @return amountReceivedLD Amount actually released to recipient.
    function _credit(
        address _to,
        uint256 _amountLD,
        uint32 _srcEid
    ) internal virtual override returns (uint256 amountReceivedLD) {
        if (_srcEid == 0) {
            // no-op to keep explicit source eid in signature for future path-specific controls
        }
        if (paused()) revert ContractPaused();

        amountReceivedLD = _amountLD;
        bridgedAmount -= amountReceivedLD;

        // slither-disable-next-line reentrancy-no-eth
        IERC20(token()).safeTransfer(_to, amountReceivedLD);
    }

    /// @notice Returns mesh-wide shared decimals used for LayerZero OFT normalization.
    /// @dev 18 local decimals and 6 shared decimals imply a 1e12 conversion factor; 10M total supply remains far below uint64 shared-units max.
    /// @return Shared decimal count for cross-chain amount normalization.
    function sharedDecimals() public pure override returns (uint8) {
        return 6;
    }

    /// @notice Validates that an address argument is non-zero.
    /// @dev Reverts with ZeroAddress when addr is the zero address.
    /// @param addr Address value to validate.
    /// @return The same address value when validation succeeds.
    function _requireNonZero(address addr) private pure returns (address) {
        if (addr == address(0)) revert ZeroAddress();
        return addr;
    }
}
