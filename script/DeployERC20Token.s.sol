// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/Script.sol";
import {Hooks} from "@uniswap/v4-core/contracts/libraries/Hooks.sol";
//import {PoolManager} from "@uniswap/v4-core/contracts/PoolManager.sol";
import {PoolManager} from "v4-minimal/contracts/PoolManager.sol";
import {HookMiner} from "../test/utils/HookMiner.sol";
import {TestERC20} from "../test/utils/TestERC20.sol";
import {Constants} from "./Constants.sol";

contract DeployERC20Token is Script {
    function setUp() public {}

    function run() public {
        vm.startBroadcast();
        uint256 amount = 2 ** 128;
        TestERC20 tokenA = new TestERC20("WrappedETH", "testETH", amount);
        TestERC20 tokenB = new TestERC20("USDC", "testUSDC", amount);

        address token0;
        address token1;
        if (address(tokenA) < address(tokenB)) {
            token0 = address(tokenA);
            token1 = address(tokenB);
        } else {
            token0 = address(tokenB);
            token1 = address(tokenA);
        }
        console.log(address(token0));
        console.log(address(token1));

        tokenA.mint(Constants.USER, amount);
        tokenB.mint(Constants.USER, amount);

        // console.log(
        //     "Balance=> TokenA: ",
        //     _tokenA.balanceOf(Constants.USER),
        //     " ,TokenB: ",
        //     _tokenB.balanceOf(Constants.USER)
        // );

        // APPROVE MANAGER FOR LP
        tokenA.approve(Constants.POOL_MANAGER, amount);
        tokenB.approve(Constants.POOL_MANAGER, amount);

        vm.stopBroadcast();
    }
}
