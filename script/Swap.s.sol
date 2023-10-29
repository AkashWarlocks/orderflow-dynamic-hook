// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/Script.sol";
//import {PoolManager} from "@uniswap/v4-core/contracts/PoolManager.sol";
import {PoolManager} from "v4-minimal/contracts/PoolManager.sol";
import {IPoolManager} from "v4-minimal/contracts/interfaces/IPoolManager.sol";
import {TestERC20} from "../test/utils/TestERC20.sol";

import {HookMiner} from "../test/utils/HookMiner.sol";
import {Constants} from "./Constants.sol";
import {CurrencyLibrary, Currency} from "v4-minimal/contracts/libraries/CurrencyLibrary.sol";
import {FeeLibrary} from "v4-minimal/contracts/libraries/FeeLibrary.sol";
import {IHooks} from "v4-minimal/contracts/interfaces/IHooks.sol";

contract Swap is Script {
    function setUp() public {}

    function run() public {
        vm.startBroadcast();
        IPoolManager manager = IPoolManager(Constants.POOL_MANAGER);

        address token0 = Constants.token0;
        address token1 = Constants.token1;
        // TestERC20 _tokenA = TestERC20(testETH);
        // TestERC20 _tokenB = TestERC20(testUSDC);
        // APPROVE MANAGER FOR USER
        // token0.approve(Constants.POOL_MANAGER, 10 ** 18);
        // token1.approve(Constants.POOL_MANAGER, 10 ** 18);

        IPoolManager.PoolKey memory poolKey = IPoolManager.PoolKey({
            currency0: Currency.wrap(token0),
            currency1: Currency.wrap(token1),
            fee: 3000 | FeeLibrary.DYNAMIC_FEE_FLAG,
            tickSpacing: 60,
            hooks: IHooks(Constants.DISCRIMINATOR_HOOK)
        });
        uint256 amount = 1000000 gwei;
        bool zeroForOne = true;

        IPoolManager.SwapParams memory params = IPoolManager.SwapParams({
            zeroForOne: zeroForOne,
            amountSpecified: int256(amount),
            sqrtPriceLimitX96: zeroForOne
                ? Constants.MIN_PRICE_LIMIT
                : Constants.MAX_PRICE_LIMIT // unlimited impact
        });

        // console.log(
        //     "BalanceBeforeSWap=> TokenA: ",
        //     token0.balanceOf(Constants.USER),
        //     " ,TokenB: ",
        //     token1.balanceOf(Constants.USER)
        // );

        manager.swap(poolKey, params);

        //console.log(address(manager));

        // console.log(
        //     "BalanceAfterSwap=> TokenA: ",
        //     _tokenA.balanceOf(Constants.USER),
        //     " ,TokenB: ",
        //     _tokenB.balanceOf(Constants.USER)
        // );

        vm.stopBroadcast();
    }
}
