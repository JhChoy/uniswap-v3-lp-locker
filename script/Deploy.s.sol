// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {console, Script} from "forge-std/Script.sol";

import {UniV3PermanentLockerFactory} from "../src/UniV3PermanentLockerFactory.sol";

interface ICreateX {
    function deployCreate2(bytes32 salt, bytes memory initCode) external payable returns (address newContract);
}

contract DeployScript is Script {
    address constant CREATEX_ADDRESS = 0xba5Ed099633D3B313e4D5F7bdc1305d3c28ba5Ed;

    modifier broadcast() {
        vm.startBroadcast();
        _;
        vm.stopBroadcast();
    }

    function _encodeRedeployableSalt(address msgSender, bytes11 salt) internal pure returns (bytes32 encodedSalt) {
        assembly {
            encodedSalt := or(shl(96, msgSender), shr(168, shl(168, salt)))
        }
    }

    function deploy(address positionManager) public broadcast {
        bytes32 salt = _encodeRedeployableSalt(msg.sender, bytes11(0));
        address deployed = ICreateX(CREATEX_ADDRESS)
            .deployCreate2(
                salt, abi.encodePacked(type(UniV3PermanentLockerFactory).creationCode, abi.encode(positionManager))
            );
        console.log("Deployed to", deployed);
    }
}
