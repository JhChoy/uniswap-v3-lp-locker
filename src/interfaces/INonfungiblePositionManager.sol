// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {IERC721Permit} from "./IERC721Permit.sol";

/// @notice Minimal interface for Uniswap V3 NonfungiblePositionManager
/// See https://github.com/Uniswap/v3-periphery/blob/0682387198a24c7cd63566a2c58398533860a5d1/contracts/interfaces/INonfungiblePositionManager.sol
interface INonfungiblePositionManager is IERC721Permit {
    struct CollectParams {
        uint256 tokenId;
        address recipient;
        uint128 amount0Max;
        uint128 amount1Max;
    }

    function safeTransferFrom(address from, address to, uint256 tokenId) external;

    function collect(CollectParams calldata params) external payable returns (uint256 amount0, uint256 amount1);
}
