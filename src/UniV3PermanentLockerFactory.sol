// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {CREATE3} from "solady/utils/CREATE3.sol";

import {INonfungiblePositionManager} from "./interfaces/INonfungiblePositionManager.sol";
import {UniV3PermanentLocker} from "./UniV3PermanentLocker.sol";

/// @title UniV3PermanentLockerFactory
/// @notice Factory contract for deploying deterministic UniV3PermanentLocker instances
/// @author JChoy
contract UniV3PermanentLockerFactory {
    /// @notice The Uniswap V3 NonfungiblePositionManager contract
    INonfungiblePositionManager public immutable POSITION_MANAGER;

    /// @notice Thrown when the deployed locker address does not match the predicted address
    error DeployFailed();

    constructor(address _positionManager) {
        POSITION_MANAGER = INonfungiblePositionManager(_positionManager);
    }

    /// @notice Deploys a new UniV3PermanentLocker contract for the given token ID
    /// @param owner The owner address of the locker
    /// @param tokenId The token ID of the Uniswap V3 LP position to lock
    /// @return The address of the deployed locker contract
    /// @dev The caller must have approved this factory to transfer the NFT, or use deployWithPermit
    function deploy(address owner, uint256 tokenId) external returns (address) {
        return _deploy(owner, tokenId);
    }

    /// @notice Deploys a new UniV3PermanentLocker contract using ERC721 permit
    /// @param owner The owner address of the locker
    /// @param tokenId The token ID of the Uniswap V3 LP position to lock
    /// @param deadline The deadline for the permit signature
    /// @param v The recovery byte of the signature
    /// @param r Half of the ECDSA signature pair
    /// @param s Half of the ECDSA signature pair
    /// @return The address of the deployed locker contract
    /// @dev Uses ERC721 permit to approve this factory without a prior approval transaction
    function deployWithPermit(address owner, uint256 tokenId, uint256 deadline, uint8 v, bytes32 r, bytes32 s)
        external
        returns (address)
    {
        POSITION_MANAGER.permit(address(this), tokenId, deadline, v, r, s);
        return _deploy(owner, tokenId);
    }

    function _deploy(address owner, uint256 tokenId) internal returns (address locker) {
        address predicted = predict(tokenId);
        POSITION_MANAGER.safeTransferFrom(msg.sender, predicted, tokenId);
        locker = CREATE3.deployDeterministic(
            abi.encodePacked(type(UniV3PermanentLocker).creationCode, abi.encode(POSITION_MANAGER, owner, tokenId)),
            bytes32(tokenId)
        );
        if (locker != predicted) {
            revert DeployFailed();
        }
    }

    /// @notice Predicts the address where a locker will be deployed for a given token ID
    /// @param tokenId The token ID of the Uniswap V3 LP position
    /// @return The predicted address of the locker contract
    function predict(uint256 tokenId) public view returns (address) {
        return CREATE3.predictDeterministicAddress(bytes32(tokenId));
    }
}
