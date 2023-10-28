// SPDX-License-Identifier: UNLICENSED
// Updated solidity
pragma solidity ^0.8.21;

// Foundry libraries
import "forge-std/Test.sol";
import "forge-std/console.sol";
import {GasSnapshot} from "forge-gas-snapshot/GasSnapshot.sol";

// Test ERC-20 token implementation
import {TestERC20} from "v4-core/test/TestERC20.sol";

// Libraries
import {CurrencyLibrary, Currency} from "v4-core/types/Currency.sol";
import {PoolId, PoolIdLibrary} from "v4-core/types/PoolId.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {Hooks} from "v4-core/libraries/Hooks.sol";
import {TickMath} from "v4-core/libraries/TickMath.sol";
import {FeeLibrary} from "v4-core/libraries/FeeLibrary.sol";
//import {Deployers} from "v4-core/test/foundry-tests/utils/Deployers.sol";
import {Deployers} from "@uniswap/v4-core/test/foundry-tests/utils/Deployers.sol";
// Interfaces
import {IHooks} from "v4-core/interfaces/IHooks.sol";
import {IERC20Minimal} from "v4-core/interfaces/external/IERC20Minimal.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";

// Pool Manager related contracts
import {PoolManager} from "v4-core/PoolManager.sol";
import {PoolModifyPositionTest} from "v4-core/test/PoolModifyPositionTest.sol";
import {PoolSwapTest} from "v4-core/test/PoolSwapTest.sol";

// Our contracts
import {HookTest} from "./utils/HookTest.sol";
import {CounterStub} from "../src/CounterStub.sol";
import {CounterHook} from "../src/CounterHook.sol";
import {HookMiner} from "./utils/HookMiner.sol";

contract CounterTest is HookTest, Deployers, GasSnapshot {
    using PoolIdLibrary for PoolKey;
    using CurrencyLibrary for Currency;

    CounterHook counter;
    PoolKey poolKey;
    PoolId poolId;

    function setUp() public {
        // creates the pool manager, test tokens, and other utility routers
        HookTest.initHookTestEnv();

        // Deploy the hook to an address with the correct flags
        uint160 flags = uint160(
            Hooks.BEFORE_SWAP_FLAG | Hooks.AFTER_SWAP_FLAG | Hooks.BEFORE_MODIFY_POSITION_FLAG
                | Hooks.AFTER_MODIFY_POSITION_FLAG
        );
        (address hookAddress, bytes32 salt) =
            HookMiner.find(address(this), flags, 0, type(CounterHook).creationCode, abi.encode(address(manager)));
        counter = new CounterHook{salt: salt}(IPoolManager(address(manager)));
        require(address(counter) == hookAddress, "CounterTest: hook address mismatch");

        // Create the pool
        poolKey = PoolKey(Currency.wrap(address(token0)), Currency.wrap(address(token1)), 3000, 60, IHooks(counter));
        poolId = poolKey.toId();
        manager.initialize(poolKey, SQRT_RATIO_1_1, ZERO_BYTES);

        // Provide liquidity to the pool
        modifyPositionRouter.modifyPosition(poolKey, IPoolManager.ModifyPositionParams(-60, 60, 10 ether));
        modifyPositionRouter.modifyPosition(poolKey, IPoolManager.ModifyPositionParams(-120, 120, 10 ether));
        modifyPositionRouter.modifyPosition(
            poolKey,
            IPoolManager.ModifyPositionParams(TickMath.minUsableTick(60), TickMath.maxUsableTick(60), 10 ether)
        );
    }

    function testCounterHooks() public {
        // positions were created in setup()
        assertEq(counter.beforeModifyPositionCount(poolId), 3);
        assertEq(counter.afterModifyPositionCount(poolId), 3);

        assertEq(counter.beforeSwapCount(poolId), 0);
        assertEq(counter.afterSwapCount(poolId), 0);

        // Perform a test swap //
        int256 amount = 100;
        bool zeroForOne = true;
        swap(poolKey, amount, zeroForOne);
        // ------------------- //

        assertEq(counter.beforeSwapCount(poolId), 1);
        assertEq(counter. (poolId), 1);
    }
}


