// SPDX-License-Identifier: UNLICENSED
// Updated solidity
pragma solidity ^0.8.20;

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
import {OrderflowDescriminator} from "../src/OrderflowDescriminator.sol";
import {HookMiner} from "./utils/HookMiner.sol";

contract DescriminatorTest is HookTest, Deployers, GasSnapshot {
    using PoolIdLibrary for PoolKey;
    using CurrencyLibrary for Currency;

    OrderflowDescriminator counter;
    PoolKey poolKey;
    PoolId poolId;

    address LP = vm.addr(1);
    address SWAPPER = address(this);

    function setUp() public {
        // creates the pool manager, test tokens, and other utility routers
        HookTest.initHookTestEnv();

        // Deploy the hook to an address with the correct flags
        uint160 flags = uint160(
            Hooks.BEFORE_INITIALIZE_FLAG |
                Hooks.BEFORE_SWAP_FLAG |
                Hooks.AFTER_SWAP_FLAG
        );
        (address hookAddress, bytes32 salt) = HookMiner.find(
            address(this),
            flags,
            0,
            type(OrderflowDescriminator).creationCode,
            abi.encode(address(manager))
        );
        counter = new OrderflowDescriminator{salt: salt}(
            IPoolManager(address(manager))
        );
        require(
            address(counter) == hookAddress,
            "CounterTest: hook address mismatch"
        );

        counter.setFee(123);

        // Create the pool as LP

        vm.startPrank(LP);
        poolKey = PoolKey({
            currency0: Currency.wrap(address(token0)),
            currency1: Currency.wrap(address(token1)),
            fee: 3000 | FeeLibrary.DYNAMIC_FEE_FLAG,
            tickSpacing: 60,
            hooks: IHooks(counter)
        });

        poolId = poolKey.toId();
        manager.initialize(poolKey, SQRT_RATIO_1_1, ZERO_BYTES);

        // Provide liquidity to the pool
        modifyPositionRouter.modifyPosition(
            poolKey,
            IPoolManager.ModifyPositionParams(-60, 60, 10 ether)
        );
        modifyPositionRouter.modifyPosition(
            poolKey,
            IPoolManager.ModifyPositionParams(-120, 120, 10 ether)
        );
        modifyPositionRouter.modifyPosition(
            poolKey,
            IPoolManager.ModifyPositionParams(
                TickMath.minUsableTick(60),
                TickMath.maxUsableTick(60),
                10 ether
            )
        );
        vm.stopPrank();
    }

    function testSwap() public {
        // positions were created in setup()

        uint256 balanceToken0Before = token0.balanceOf(SWAPPER);
        uint256 balanceToken1Before = token1.balanceOf(SWAPPER);

        console.log(balanceToken0Before);
        console.log(balanceToken1Before);

        // Perform a test swap //
        uint256 amount = 1 ether;
        bool zeroForOne = true;
        swap(poolKey, int256(amount), zeroForOne);
        // ------------------- //

        uint256 balanceToken0After = token0.balanceOf(SWAPPER);
        uint256 balanceToken1After = token1.balanceOf(SWAPPER);

        console.log(balanceToken0After);
        console.log(balanceToken1After);

        console.log("Amount token0 in: %s", amount);

        console.log(
            "Amount token1 received: %s",
            balanceToken1After - balanceToken1Before
        );

        assertLt(balanceToken0After, balanceToken0Before);
        assertGt(balanceToken1After, balanceToken1Before);
    }
}
