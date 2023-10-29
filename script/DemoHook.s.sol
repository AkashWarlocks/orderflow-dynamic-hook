// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/Script.sol";
//import {PoolManager} from "@uniswap/v4-core/contracts/PoolManager.sol";
import {PoolManager} from "v4-minimal/contracts/PoolManager.sol";
import {IPoolManager} from "v4-minimal/contracts/interfaces/IPoolManager.sol";
import {TickMath} from "v4-minimal/contracts/libraries/TickMath.sol";
import {TestERC20} from "../test/utils/TestERC20.sol";

import {HookMiner} from "../test/utils/HookMiner.sol";
import {Constants} from "./Constants.sol";
import {CurrencyLibrary, Currency} from "v4-minimal/contracts/libraries/CurrencyLibrary.sol";
import {FeeLibrary} from "v4-minimal/contracts/libraries/FeeLibrary.sol";
import {IHooks} from "v4-minimal/contracts/interfaces/IHooks.sol";
import {BalanceDelta} from "v4-minimal/contracts/types/BalanceDelta.sol";

contract DemoHook is Script {
    function setUp() public {}

    function run() public {
        vm.startBroadcast();
        address token0 = Constants.token0;
        address token1 = Constants.token1;
        TestERC20 nToken0 = TestERC20(token0);
        TestERC20 nToken1 = TestERC20(token1);
        IPoolManager manager = IPoolManager(Constants.POOL_MANAGER);

        IPoolManager.PoolKey memory poolKey = IPoolManager.PoolKey({
            currency0: Currency.wrap(token0),
            currency1: Currency.wrap(token1),
            fee: 3000 | FeeLibrary.DYNAMIC_FEE_FLAG,
            tickSpacing: 60,
            hooks: IHooks(Constants.DISCRIMINATOR_HOOK)
        });
        nToken0.approve(Constants.USER, 100 ether);
        nToken1.approve(Constants.USER, 100 ether);

        manager.initialize(poolKey, Constants.SQRT_RATIO_1_1);

        manager.modifyPosition(
            poolKey,
            IPoolManager.ModifyPositionParams(-60, 60, 10 ether)
        );
        manager.modifyPosition(
            poolKey,
            IPoolManager.ModifyPositionParams(-120, 120, 10 ether)
        );
        manager.modifyPosition(
            poolKey,
            IPoolManager.ModifyPositionParams(
                TickMath.minUsableTick(60),
                TickMath.maxUsableTick(60),
                50 ether
            )
        );

        // console.log(address(manager));
        //console.log("ID: ", poolKey.toId());
        vm.stopBroadcast();
    }
}
