// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {Ownable} from "solady/auth/Ownable.sol";

import {INonfungiblePositionManager} from "./interfaces/INonfungiblePositionManager.sol";

/// @title UniV3PermanentLocker
/// @notice Locks a single Uniswap V3 LP NFT forever, but allows fee collection.
/// @author JChoy
contract UniV3PermanentLocker is IERC721Receiver, Ownable {
    /// @notice The Uniswap V3 NonfungiblePositionManager contract
    INonfungiblePositionManager public immutable POSITION_MANAGER;

    /// @notice The token ID of the locked Uniswap V3 LP position
    uint256 public immutable lockedTokenId;

    /// @notice Address that receives collected fees
    address public feeRecipient;

    /// @notice Emitted when fees are collected from the locked position
    /// @param tokenId The token ID of the position
    /// @param recipient The address that received the fees
    /// @param amount0 The amount of token0 collected
    /// @param amount1 The amount of token1 collected
    event FeesCollected(uint256 indexed tokenId, address indexed recipient, uint256 amount0, uint256 amount1);

    /// @notice Emitted when the fee recipient is updated
    /// @param previousRecipient The previous fee recipient address
    /// @param newRecipient The new fee recipient address
    event FeeRecipientUpdated(address indexed previousRecipient, address indexed newRecipient);

    /// @notice Thrown when the contract does not own the specified token ID
    error NotOwner();

    /// @notice Modifier that only checks owner if owner is not zero address.
    /// @dev If owner is zero address, allows anyone to call. Otherwise, enforces onlyOwner.
    modifier onlyOwnerIfSet() {
        _checkOwnerIfSet();
        _;
    }

    /// @notice Initializes the locker contract
    /// @param _positionManager The address of the Uniswap V3 NonfungiblePositionManager
    /// @param _owner The owner address for the locker
    /// @param _tokenId The token ID of the Uniswap V3 LP position to lock
    /// @dev The token must already be transferred to this contract before construction
    constructor(address _positionManager, address _owner, uint256 _tokenId) {
        _initializeOwner(_owner);
        POSITION_MANAGER = INonfungiblePositionManager(_positionManager);
        lockedTokenId = _tokenId;
        feeRecipient = _owner;
        if (POSITION_MANAGER.ownerOf(_tokenId) != address(this)) {
            revert NotOwner();
        }
    }

    /// @notice Collect fees from the locked position
    /// @param amount0Max Maximum amount of token0 to collect
    /// @param amount1Max Maximum amount of token1 to collect
    /// @return amount0 The amount of token0 collected
    /// @return amount1 The amount of token1 collected
    function collect(uint128 amount0Max, uint128 amount1Max) external onlyOwnerIfSet returns (uint256, uint256) {
        return _collect(amount0Max, amount1Max);
    }

    /// @notice Collect all available fees from the locked position and send them to the configured fee recipient
    /// @return amount0 The amount of token0 collected
    /// @return amount1 The amount of token1 collected
    function collectAll() external onlyOwnerIfSet returns (uint256, uint256) {
        return _collect(type(uint128).max, type(uint128).max);
    }

    /// @notice Updates the fee recipient address used for collections
    /// @param newRecipient The new fee recipient (can be set to address(0) if desired)
    function setFeeRecipient(address newRecipient) external onlyOwner {
        address previousRecipient = feeRecipient;
        feeRecipient = newRecipient;
        emit FeeRecipientUpdated(previousRecipient, newRecipient);
    }

    /// @notice Internal helper to collect fees using the configured fee recipient
    /// @param amount0Max Maximum amount of token0 to collect
    /// @param amount1Max Maximum amount of token1 to collect
    /// @return amount0 The amount of token0 collected
    /// @return amount1 The amount of token1 collected
    function _collect(uint128 amount0Max, uint128 amount1Max) internal returns (uint256 amount0, uint256 amount1) {
        address recipient = feeRecipient;
        INonfungiblePositionManager.CollectParams memory params = INonfungiblePositionManager.CollectParams({
            tokenId: lockedTokenId, recipient: recipient, amount0Max: amount0Max, amount1Max: amount1Max
        });

        (amount0, amount1) = POSITION_MANAGER.collect(params);

        emit FeesCollected(lockedTokenId, recipient, amount0, amount1);
    }

    function _checkOwnerIfSet() internal view {
        if (owner() != address(0)) {
            _checkOwner();
        }
    }

    /// @inheritdoc IERC721Receiver
    function onERC721Received(address, address, uint256, bytes calldata) external pure override returns (bytes4) {
        // Accept all ERC721 transfers (we only use one, via lock()).
        return IERC721Receiver.onERC721Received.selector;
    }
}
