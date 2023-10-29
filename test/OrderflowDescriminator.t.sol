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
import {Deployers} from "v4-minimal/test/Deployers.sol";
import {Constants} from "v4-minimal/test/utils/Constants.sol";

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

import {IFtsoRegistry} from "@flarenetwork/flare-periphery-contracts/lib/flare-foundry-periphery-package/src/coston2/ftso/userInterfaces/IFtsoRegistry.sol";
import {MockFtsoRegistry} from "@flarenetwork/flare-periphery-contracts/lib/flare-foundry-periphery-package/src/coston2/mockContracts/MockFtsoRegistry.sol";
import {MockFtso} from "@flarenetwork/flare-periphery-contracts/lib/flare-foundry-periphery-package/src/coston2/mockContracts/MockFtso.sol";

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

        // labels for stack traces
        vm.label(LP, "LP");
        vm.label(SWAPPER, "Swapper");

        // Deploy the hook to an address with the correct flags
        uint160 flags = uint160(
            Hooks.BEFORE_INITIALIZE_FLAG |
                Hooks.BEFORE_SWAP_FLAG |
                Hooks.AFTER_SWAP_FLAG
        );

        string memory symbol0 = token0.symbol();
        string memory symbol1 = token1.symbol();

        MockFtso mockFtso0 = new MockFtso(symbol0, 2);
        MockFtso mockFtso1 = new MockFtso(symbol1, 2);

        MockFtsoRegistry mockFtsoRegistry = new MockFtsoRegistry();

        mockFtsoRegistry.addFtso(mockFtso0);
        mockFtsoRegistry.addFtso(mockFtso1);

        uint256 ETH_PRICE = 195000;

        mockFtsoRegistry.setPriceForSymbol(
            token0.symbol(),
            100,
            block.timestamp,
            2
        );

        mockFtsoRegistry.setPriceForSymbol(
            token1.symbol(),
            ETH_PRICE,
            block.timestamp,
            2
        );

        (uint256 price, , ) = mockFtsoRegistry.getCurrentPriceWithDecimals(
            symbol1
        );

        assertEq(symbol1, "testETH");
        assertEq(price, ETH_PRICE);

        (address hookAddress, bytes32 salt) = HookMiner.find(
            address(this),
            flags,
            0,
            type(OrderflowDescriminator).creationCode,
            abi.encode(address(manager), address(mockFtsoRegistry))
        );

        discriminator = new OrderflowDescriminator{salt: salt}(
            IPoolManager(address(manager)),
            IFtsoRegistry(address(mockFtsoRegistry))
        );
        require(
            address(discriminator) == hookAddress,
            "CounterTest: hook address mismatch"
        );

        discriminator.setFee(5000);

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
        manager.initialize(poolKey, Constants.SQRT_RATIO_1800_1);

        // Provide liquidity to the pool
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

        // Perform a test swap //
        uint256 amount = 1 ether;
        bool zeroForOne = false;

        // Prank EOA origin behaviour, used by hook to identify swapper
        vm.prank(SWAPPER, SWAPPER);
        swap(poolKey, int256(amount), zeroForOne);
        // ------------------- //

        uint256 balanceToken0After = token0.balanceOf(SWAPPER);
        uint256 balanceToken1After = token1.balanceOf(SWAPPER);

        console.log("balance token 0 after: %s", balanceToken0After);
        console.log("balance token 1 after: %s", balanceToken1After);

        if (zeroForOne == true) {
            assertLt(balanceToken0After, balanceToken0Before);
        } else {
            assertLt(balanceToken1After, balanceToken1Before);
        }
    }
}
