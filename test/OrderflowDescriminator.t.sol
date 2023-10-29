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
import {CurrencyLibrary, Currency} from "v4-minimal/contracts/libraries/CurrencyLibrary.sol";
import {PoolId, PoolIdLibrary} from "v4-minimal/contracts/types/PoolId.sol";
import {PoolKey} from "v4-minimal/contracts/types/PoolKey.sol";
import {Hooks} from "v4-minimal/contracts/libraries/Hooks.sol";
import {TickMath} from "v4-minimal/contracts/libraries/TickMath.sol";
import {FeeLibrary} from "v4-minimal/contracts/libraries/FeeLibrary.sol";
//import {Deployers} from "v4-core/test/foundry-tests/utils/Deployers.sol";
import {Deployers} from "v4-minimal/test/Deployers.sol";
// Interfaces
import {IHooks} from "v4-minimal/contracts/interfaces/IHooks.sol";
import {IERC20Minimal} from "v4-minimal/contracts/interfaces/external/IERC20Minimal.sol";
import {IPoolManager} from "v4-minimal/contracts/interfaces/IPoolManager.sol";

// Pool Manager related contracts
import {PoolManager} from "v4-minimal/contracts/PoolManager.sol";
import {PoolSwapTest} from "v4-minimal/test/PoolSwapTest.sol";

// Our contracts
import {HookTest} from "./utils/HookTest.sol";
import {OrderflowDescriminator} from "../src/OrderflowDescriminator.sol";
import {HookMiner} from "./utils/HookMiner.sol";

contract DescriminatorTest is HookTest, Deployers, GasSnapshot {
    using PoolIdLibrary for IPoolManager.PoolKey;
    using CurrencyLibrary for Currency;

    OrderflowDescriminator discriminator;
    IPoolManager.PoolKey poolKey;
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
        discriminator = new OrderflowDescriminator{salt: salt}(
            IPoolManager(address(manager))
        );
        require(
            address(discriminator) == hookAddress,
            "CounterTest: hook address mismatch"
        );

        discriminator.setFee(123);

        // Create the pool as LP

        vm.startPrank(LP);
        poolKey = IPoolManager.PoolKey({
            currency0: Currency.wrap(address(token0)),
            currency1: Currency.wrap(address(token1)),
            fee: 3000 | FeeLibrary.DYNAMIC_FEE_FLAG,
            tickSpacing: 60,
            hooks: IHooks(discriminator)
        });

        poolId = poolKey.toId();
        manager.initialize(poolKey, SQRT_RATIO_1_1);

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

        uint256 userSwapCountBefore = discriminator.globalUserSwapCount(
            SWAPPER
        );

        console.log(userSwapCountBefore);
        console.log(SWAPPER);

        uint256 balanceToken0Before = token0.balanceOf(SWAPPER);
        uint256 balanceToken1Before = token1.balanceOf(SWAPPER);

        // Perform a test swap //
        uint256 amount = 1 ether;
        bool zeroForOne = true;

        // Prank EOA origin behaviour, used by hook to identify swapper
        vm.prank(SWAPPER, SWAPPER);
        swap(poolKey, int256(amount), zeroForOne);
        // ------------------- //

        uint256 userSwapCountAfter = discriminator.globalUserSwapCount(SWAPPER);

        uint256 balanceToken0After = token0.balanceOf(SWAPPER);
        uint256 balanceToken1After = token1.balanceOf(SWAPPER);

        console.log("Amount token0 in: %s", amount);

        console.log(
            "Amount token1 received: %s",
            balanceToken1After - balanceToken1Before
        );

        assertEq(userSwapCountAfter - userSwapCountBefore, 1);

        assertLt(balanceToken0After, balanceToken0Before);
        assertGt(balanceToken1After, balanceToken1Before);
    }
}
