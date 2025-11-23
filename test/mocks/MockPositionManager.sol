// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

import {INonfungiblePositionManager} from "../../src/interfaces/INonfungiblePositionManager.sol";

/// @notice Simple in-memory mock for the Uniswap V3 NonfungiblePositionManager
contract MockPositionManager is INonfungiblePositionManager {
    struct PermitCall {
        address spender;
        uint256 tokenId;
        uint256 deadline;
        uint8 v;
        bytes32 r;
        bytes32 s;
    }

    mapping(uint256 => address) private _owners;
    mapping(address => uint256) private _balances;
    mapping(uint256 => address) private _tokenApprovals;
    mapping(address => mapping(address => bool)) private _operatorApprovals;

    CollectParams public lastCollectParams;
    uint256 public collectAmount0;
    uint256 public collectAmount1;

    PermitCall public lastPermitCall;
    bool public permitCalled;

    /// @notice Mint helper for tests
    function mint(address to, uint256 tokenId) external {
        require(to != address(0), "zero address");
        require(_owners[tokenId] == address(0), "already minted");

        _owners[tokenId] = to;
        _balances[to] += 1;

        emit Transfer(address(0), to, tokenId);
    }

    function burn(uint256 tokenId) external {
        address owner_ = _owners[tokenId];
        require(owner_ != address(0), "not minted");
        require(msg.sender == owner_, "not owner");

        _balances[owner_] -= 1;
        delete _owners[tokenId];

        emit Transfer(owner_, address(0), tokenId);
    }

    function setCollectResult(uint256 amount0, uint256 amount1) external {
        collectAmount0 = amount0;
        collectAmount1 = amount1;
    }

    function PERMIT_TYPEHASH() external pure override returns (bytes32) {
        return keccak256("MockPermit(address spender,uint256 tokenId,uint256 deadline)");
    }

    function DOMAIN_SEPARATOR() external pure override returns (bytes32) {
        return bytes32(uint256(0xdeadbeef));
    }

    function permit(address spender, uint256 tokenId, uint256 deadline, uint8 v, bytes32 r, bytes32 s)
        external
        payable
        override
    {
        permitCalled = true;
        lastPermitCall = PermitCall({spender: spender, tokenId: tokenId, deadline: deadline, v: v, r: r, s: s});
        _tokenApprovals[tokenId] = spender;
        emit Approval(ownerOf(tokenId), spender, tokenId);
    }

    function safeTransferFrom(address from, address to, uint256 tokenId) public override {
        _safeTransfer(from, to, tokenId, "");
    }

    function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory data) public override {
        _safeTransfer(from, to, tokenId, data);
    }

    function transferFrom(address from, address to, uint256 tokenId) public override {
        require(_isApprovedOrOwner(msg.sender, tokenId), "not approved");
        _transfer(from, to, tokenId);
    }

    function approve(address to, uint256 tokenId) external override {
        address owner_ = ownerOf(tokenId);
        require(msg.sender == owner_ || isApprovedForAll(owner_, msg.sender), "not authorized");
        _tokenApprovals[tokenId] = to;
        emit Approval(owner_, to, tokenId);
    }

    function getApproved(uint256 tokenId) public view override returns (address) {
        require(_owners[tokenId] != address(0), "not minted");
        return _tokenApprovals[tokenId];
    }

    function setApprovalForAll(address operator, bool approved) external override {
        _operatorApprovals[msg.sender][operator] = approved;
        emit ApprovalForAll(msg.sender, operator, approved);
    }

    function isApprovedForAll(address owner_, address operator) public view override returns (bool) {
        return _operatorApprovals[owner_][operator];
    }

    function balanceOf(address owner_) external view override returns (uint256) {
        require(owner_ != address(0), "zero address");
        return _balances[owner_];
    }

    function ownerOf(uint256 tokenId) public view override returns (address) {
        address owner_ = _owners[tokenId];
        require(owner_ != address(0), "not minted");
        return owner_;
    }

    function collect(CollectParams calldata params)
        external
        payable
        override
        returns (uint256 amount0, uint256 amount1)
    {
        lastCollectParams = params;
        amount0 = collectAmount0;
        amount1 = collectAmount1;
    }

    function supportsInterface(bytes4 interfaceId) external pure override returns (bool) {
        return interfaceId == type(IERC165).interfaceId || interfaceId == type(INonfungiblePositionManager).interfaceId;
    }

    function _safeTransfer(address from, address to, uint256 tokenId, bytes memory data) internal {
        require(_isApprovedOrOwner(msg.sender, tokenId), "not approved");
        _transfer(from, to, tokenId);
        if (to.code.length != 0) {
            require(
                IERC721Receiver(to).onERC721Received(msg.sender, from, tokenId, data)
                    == IERC721Receiver.onERC721Received.selector,
                "unsafe recipient"
            );
        }
    }

    function _transfer(address from, address to, uint256 tokenId) internal {
        require(ownerOf(tokenId) == from, "wrong from");
        require(to != address(0), "zero to");

        delete _tokenApprovals[tokenId];
        _balances[from] -= 1;
        _balances[to] += 1;
        _owners[tokenId] = to;

        emit Transfer(from, to, tokenId);
    }

    function _isApprovedOrOwner(address spender, uint256 tokenId) internal view returns (bool) {
        address owner_ = ownerOf(tokenId);
        return (spender == owner_ || getApproved(tokenId) == spender || isApprovedForAll(owner_, spender));
    }
}

