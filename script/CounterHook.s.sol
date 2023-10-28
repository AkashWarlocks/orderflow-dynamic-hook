// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "forge-std/Script.sol";
import {Hooks} from "@uniswap/v4-core/contracts/libraries/Hooks.sol";
import {IPoolManager} from "@uniswap/v4-core/contracts/interfaces/IPoolManager.sol";
import {CounterHook} from "../src/CounterHook.sol";
import {HookMiner} from "../test/utils/HookMiner.sol";

contract CounterHookScript is Script {
    address constant CREATE2_DEPLOYER = address(0x4e59b44847b379578588920cA78FbF26c0B4956C);

    function setUp() public {}

    function run() public {
        IPoolManager manager = IPoolManager(payable(0xC7f2Cf4845C6db0e1a1e91ED41Bcd0FcC1b0E141));

        // hook contracts must have specific flags encoded in the address
        uint160 flags = uint160(
            Hooks.BEFORE_SWAP_FLAG | Hooks.AFTER_SWAP_FLAG | Hooks.BEFORE_MODIFY_POSITION_FLAG
                | Hooks.AFTER_MODIFY_POSITION_FLAG
        );
        // Mine a salt that will produce a hook address with the correct flags
        (address hookAddress, bytes32 salt) = HookMiner.find(CREATE2_DEPLOYER, flags, 1000, type(CounterHook).creationCode, abi.encode(address(manager)));

        // Deploy the hook using CREATE2
        vm.broadcast();
        CounterHook hook = new CounterHook{salt: salt}(manager);
        console.log(hookAddress);
        require(address(hook) == hookAddress, "Script: hook address mismatch");
    }
}