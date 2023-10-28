// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/Script.sol";
import {Hooks} from "@uniswap/v4-core/contracts/libraries/Hooks.sol";
//import {PoolManager} from "@uniswap/v4-core/contracts/PoolManager.sol";
import {PoolManager} from "v4-minimal/contracts/PoolManager.sol";
import {HookMiner} from "../test/utils/HookMiner.sol";

contract DeployPoolManager is Script {
    function setUp() public {}

    function run() public {
        vm.startBroadcast();
        PoolManager manager = new PoolManager(500000);
        console.log(address(manager));
        vm.stopBroadcast();
    }
}
