// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/Script.sol";
import {Hooks} from "@uniswap/v4-core/contracts/libraries/Hooks.sol";
import {PoolManager} from "@uniswap/v4-core/contracts/PoolManager.sol";
import {HookMiner} from "../test/utils/HookMiner.sol";

contract DeployPoolManager is Script {
    address constant CREATE2_DEPLOYER =
        address(0x4e59b44847b379578588920cA78FbF26c0B4956C);

    function setUp() public {}

    function run() public {
        PoolManager manager = new PoolManager(500000);
        // Deploy the hook using CREATE2
        console.log(address(manager));
        vm.broadcast();
    }
}
