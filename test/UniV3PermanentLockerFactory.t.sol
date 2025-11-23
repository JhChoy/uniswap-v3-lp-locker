// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";

import {UniV3PermanentLocker} from "../src/UniV3PermanentLocker.sol";
import {UniV3PermanentLockerFactory} from "../src/UniV3PermanentLockerFactory.sol";
import {MockPositionManager} from "./mocks/MockPositionManager.sol";

contract UniV3PermanentLockerFactoryTest is Test {
    MockPositionManager internal positionManager;
    UniV3PermanentLockerFactory internal factory;

    address internal lpHolder = makeAddr("lpHolder");
    address internal lockerOwner = makeAddr("lockerOwner");
    uint256 internal constant TOKEN_ID = 4242;

    function setUp() public {
        positionManager = new MockPositionManager();
        factory = new UniV3PermanentLockerFactory(address(positionManager));
    }

    function testDeployLocksTokenAndInitializesLocker() public {
        _mintAndApprove(lpHolder, TOKEN_ID);

        address predicted = factory.predict(TOKEN_ID);

        vm.prank(lpHolder);
        address lockerAddr = factory.deploy(lockerOwner, TOKEN_ID);

        assertEq(lockerAddr, predicted, "predict mismatch");
        assertEq(positionManager.ownerOf(TOKEN_ID), lockerAddr, "token not locked");

        UniV3PermanentLocker locker = UniV3PermanentLocker(lockerAddr);
        assertEq(locker.lockedTokenId(), TOKEN_ID, "tokenId mismatch");
        assertEq(locker.owner(), lockerOwner, "owner mismatch");
        assertEq(address(locker.POSITION_MANAGER()), address(positionManager), "manager mismatch");
    }

    function testDeployWithPermitApprovesFactory() public {
        positionManager.mint(lpHolder, TOKEN_ID);

        uint256 deadline = block.timestamp + 1 days;
        uint8 v = 27;
        bytes32 r = keccak256("r");
        bytes32 s = keccak256("s");

        vm.prank(lpHolder);
        address lockerAddr = factory.deployWithPermit(lockerOwner, TOKEN_ID, deadline, v, r, s);

        assertTrue(positionManager.permitCalled(), "permit not used");
        (
            address spender,
            uint256 permitTokenId,
            uint256 permitDeadline,
            uint8 permitV,
            bytes32 permitR,
            bytes32 permitS
        ) = positionManager.lastPermitCall();

        assertEq(spender, address(factory), "wrong spender");
        assertEq(permitTokenId, TOKEN_ID, "wrong token id");
        assertEq(permitDeadline, deadline, "wrong deadline");
        assertEq(permitV, v, "wrong v");
        assertEq(permitR, r, "wrong r");
        assertEq(permitS, s, "wrong s");
        assertEq(positionManager.ownerOf(TOKEN_ID), lockerAddr, "token not locked");
    }

    function testPredictStablePerTokenId() public view {
        address addr1 = factory.predict(1);
        address addr2 = factory.predict(1);
        address addr3 = factory.predict(2);

        assertEq(addr1, addr2, "predict not deterministic");
        assertTrue(addr1 != addr3, "different ids should differ");
    }

    function _mintAndApprove(address holder, uint256 tokenId) internal {
        positionManager.mint(holder, tokenId);
        vm.prank(holder);
        positionManager.approve(address(factory), tokenId);
    }
}

