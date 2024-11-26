// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import {Script, console} from "forge-std/Script.sol";
import {Auxion} from "../src/Auxion.sol";

contract AuxionScript is Script {
    Auxion auxion;

    function setUp() public {
        vm.createSelectFork(vm.rpcUrl("lisk_sepolia"));
    }

    function run() public {
        uint256 privateKey = vm.envUint("DEPLOYER_WALLET_PRIVATE_KEY");
        vm.startBroadcast(privateKey);
        auxion = new Auxion();
        vm.stopBroadcast();
    }
}