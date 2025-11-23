// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";

import {Ownable} from "solady/auth/Ownable.sol";

import {UniV3PermanentLocker} from "../src/UniV3PermanentLocker.sol";
import {UniV3PermanentLockerFactory} from "../src/UniV3PermanentLockerFactory.sol";
import {INonfungiblePositionManager} from "../src/interfaces/INonfungiblePositionManager.sol";
import {MockPositionManager} from "./mocks/MockPositionManager.sol";

contract UniV3PermanentLockerTest is Test {
    MockPositionManager internal positionManager;
    UniV3PermanentLockerFactory internal factory;

    address internal lpHolder = makeAddr("lpHolder");
    address internal feeRecipient = makeAddr("feeRecipient");
    address internal lockerOwner = makeAddr("lockerOwner");
    uint256 internal constant TOKEN_ID = 1337;

    event FeesCollected(uint256 indexed tokenId, address indexed recipient, uint256 amount0, uint256 amount1);

    function setUp() public {
        positionManager = new MockPositionManager();
        factory = new UniV3PermanentLockerFactory(address(positionManager));
    }

    function testConstructorRevertsWhenNotTokenOwner() public {
        positionManager.mint(lpHolder, TOKEN_ID);

        vm.expectRevert(UniV3PermanentLocker.NotOwner.selector);
        new UniV3PermanentLocker(address(positionManager), lockerOwner, TOKEN_ID);
    }

    function testCollectByOwnerPullsFees() public {
        UniV3PermanentLocker locker = _deployLocker(TOKEN_ID, lockerOwner);
        positionManager.setCollectResult(1e18, 2e18);

        vm.prank(lockerOwner);
        locker.setFeeRecipient(feeRecipient);

        vm.expectEmit(true, true, false, true);
        emit FeesCollected(TOKEN_ID, feeRecipient, 1e18, 2e18);
        vm.prank(lockerOwner);
        (uint256 amount0, uint256 amount1) = locker.collect(25, 50);

        assertEq(amount0, 1e18, "amount0 mismatch");
        assertEq(amount1, 2e18, "amount1 mismatch");

        (uint256 calledTokenId, address calledRecipient, uint128 amount0Max, uint128 amount1Max) =
            positionManager.lastCollectParams();

        assertEq(calledTokenId, TOKEN_ID, "tokenId mismatch");
        assertEq(calledRecipient, feeRecipient, "recipient mismatch");
        assertEq(amount0Max, 25, "amount0Max mismatch");
        assertEq(amount1Max, 50, "amount1Max mismatch");
    }

    function testCollectRevertsForNonOwner() public {
        UniV3PermanentLocker locker = _deployLocker(TOKEN_ID, lockerOwner);
        address attacker = makeAddr("attacker");

        vm.expectRevert(Ownable.Unauthorized.selector);
        vm.prank(attacker);
        locker.collect(1, 1);
    }

    function testCollectAllowedAfterRenounce() public {
        UniV3PermanentLocker locker = _deployLocker(TOKEN_ID, lockerOwner);
        positionManager.setCollectResult(5, 7);

        vm.prank(lockerOwner);
        locker.renounceOwnership();

        address randomCaller = makeAddr("random");
        vm.prank(randomCaller);
        (uint256 amount0, uint256 amount1) = locker.collect(10, 11);

        assertEq(amount0, 5);
        assertEq(amount1, 7);
    }

    function testCollectAllUsesOwnerRecipient() public {
        UniV3PermanentLocker locker = _deployLocker(TOKEN_ID, lockerOwner);
        positionManager.setCollectResult(9, 4);

        vm.prank(lockerOwner);
        (uint256 amount0, uint256 amount1) = locker.collectAll();

        assertEq(amount0, 9);
        assertEq(amount1, 4);

        (uint256 calledTokenId, address calledRecipient, uint128 amount0Max, uint128 amount1Max) =
            positionManager.lastCollectParams();

        assertEq(calledTokenId, TOKEN_ID);
        assertEq(calledRecipient, lockerOwner);
        assertEq(amount0Max, type(uint128).max);
        assertEq(amount1Max, type(uint128).max);
    }

    function testCollectAllAfterRenounceUsesZeroRecipient() public {
        UniV3PermanentLocker locker = _deployLocker(TOKEN_ID, lockerOwner);
        positionManager.setCollectResult(3, 6);

        vm.prank(lockerOwner);
        locker.setFeeRecipient(address(0));
        vm.prank(lockerOwner);
        locker.renounceOwnership();

        vm.prank(makeAddr("anyone"));
        locker.collectAll();

        (, address calledRecipient,,) = positionManager.lastCollectParams();
        assertEq(calledRecipient, address(0), "recipient should be zero");
    }

    function _deployLocker(uint256 tokenId, address owner_) internal returns (UniV3PermanentLocker locker) {
        positionManager.mint(lpHolder, tokenId);
        vm.prank(lpHolder);
        positionManager.approve(address(factory), tokenId);

        vm.prank(lpHolder);
        address lockerAddr = factory.deploy(owner_, tokenId);
        locker = UniV3PermanentLocker(payable(lockerAddr));
    }

    function testSetFeeRecipientOnlyOwner() public {
        UniV3PermanentLocker locker = _deployLocker(TOKEN_ID, lockerOwner);
        address newRecipient = makeAddr("newRecipient");

        vm.prank(lockerOwner);
        locker.setFeeRecipient(newRecipient);
        assertEq(locker.feeRecipient(), newRecipient);

        address attacker = makeAddr("attacker");
        vm.expectRevert(Ownable.Unauthorized.selector);
        vm.prank(attacker);
        locker.setFeeRecipient(feeRecipient);
    }
}

