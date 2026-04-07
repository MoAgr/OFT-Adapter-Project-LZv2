// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {OFT} from "@layerzerolabs/oft-evm/contracts/OFT.sol";
import {
    RateLimiter
} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/utils/RateLimiter.sol";
import {Pausable} from "@openzeppelin/contracts/security/Pausable.sol";

/// @notice Remote-chain OFT for LegacyToken using mint-on-receive and burn-on-send behavior.
/// @dev Canonical supply remains on Sepolia lockbox; this contract represents synthetic remote supply under OFT accounting.
contract LegacyTokenOFT is OFT, RateLimiter, Pausable {
    error ContractPaused();
    error ZeroAddress();

    /// @notice Deploys a remote OFT instance and sets a non-zero LayerZero delegate.
    /// @param name_ Token name.
    /// @param symbol_ Token symbol.
    /// @param lzEndpoint_ LayerZero endpoint for this remote chain.
    /// @param delegate_ Delegate allowed to manage emergency LayerZero config.
    constructor(
        string memory name_,
        string memory symbol_,
        address lzEndpoint_,
        address delegate_
    ) OFT(name_, symbol_, _requireNonZero(lzEndpoint_), msg.sender) {
        if (delegate_ == address(0)) revert ZeroAddress();
        setDelegate(delegate_);
    }

    /// @notice Pauses bridge debit/credit execution.
    function pause() external onlyOwner {
        _pause();
    }

    /// @notice Unpauses bridge debit/credit execution.
    function unpause() external onlyOwner {
        _unpause();
    }

    /// @notice Sets per-destination rate limits for outbound sends.
    /// @dev Each config entry sets destination eid, token limit, and window size in seconds.
    /// @param rateLimitConfigs Array of destination rate limit configurations.
    function setRateLimits(
        RateLimiter.RateLimitConfig[] calldata rateLimitConfigs
    ) external onlyOwner {
        _setRateLimits(rateLimitConfigs);
    }

    /// @notice Burns tokens for outbound sends after parent OFT normalization.
    /// @param _from Sender address on this chain.
    /// @param _amountLD Requested local-decimal amount.
    /// @param _minAmountLD Minimum acceptable amount after normalization.
    /// @param _dstEid Destination endpoint ID.
    /// @return amountSentLD Cleaned local-decimal amount debited.
    /// @return amountReceivedLD Destination-side receive amount representation.
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

        (amountSentLD, amountReceivedLD) = super._debit(
            _from,
            _amountLD,
            _minAmountLD,
            _dstEid
        );
        _checkAndUpdateRateLimit(_dstEid, amountSentLD);
    }

    /// @notice Mints tokens for inbound receive path.
    /// @param _to Receiver address on this chain.
    /// @param _amountLD Local-decimal amount to credit.
    /// @param _srcEid Source endpoint ID.
    /// @return amountReceivedLD Amount credited by the parent OFT implementation.
    function _credit(
        address _to,
        uint256 _amountLD,
        uint32 _srcEid
    ) internal virtual override returns (uint256 amountReceivedLD) {
        if (paused()) revert ContractPaused();
        amountReceivedLD = super._credit(_to, _amountLD, _srcEid);
    }

    /// @notice Returns mesh-wide shared decimals used for LayerZero OFT normalization.
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
