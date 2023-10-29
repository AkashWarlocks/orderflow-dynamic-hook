// SPDX-License-Identifier: UNLICENSED
// Updated solidity
pragma solidity ^0.8.20;

// Foundry libraries
import "forge-std/Script.sol";
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
import {Hook} from "./Hook.s.sol";
import {OrderflowDescriminator} from "../src/OrderflowDescriminator.sol";
import {HookMiner} from "../test/utils/HookMiner.sol";

import {IFtsoRegistry} from "@flarenetwork/flare-periphery-contracts/lib/flare-foundry-periphery-package/src/coston2/ftso/userInterfaces/IFtsoRegistry.sol";
import {MockFtsoRegistry} from "@flarenetwork/flare-periphery-contracts/lib/flare-foundry-periphery-package/src/coston2/mockContracts/MockFtsoRegistry.sol";
import {MockFtso} from "@flarenetwork/flare-periphery-contracts/lib/flare-foundry-periphery-package/src/coston2/mockContracts/MockFtso.sol";

contract MainDeploy is Hook, Deployers, GasSnapshot {
    using PoolIdLibrary for IPoolManager.PoolKey;
    using CurrencyLibrary for Currency;

    OrderflowDescriminator discriminator;
    IPoolManager.PoolKey poolKey;
    PoolId poolId;

    address aLP;
    address aSWAPPER;

    function setUp() public {}

    function run() public {
        /**
         * Read Enviornment Variables
         * aLP: Liquidity Provider User
         * aSwapper: Swapper user
         * */
        uint256 privKey1 = vm.envUint("LP");
        uint256 privKey2 = vm.envUint("USER");
        aLP = vm.rememberKey(privKey1);
        aSWAPPER = vm.rememberKey(privKey2);
        vm.startBroadcast(aLP);

        Hook.initHookEnv();

        // Deploy the hook to an address with the correct flags
        uint160 flags = uint160(
            Hooks.BEFORE_INITIALIZE_FLAG |
                Hooks.BEFORE_SWAP_FLAG |
                Hooks.AFTER_SWAP_FLAG
        );

        // Deploy Hook contract using CREATE_2
        (address hookAddress, bytes32 salt) = HookMiner.find(
            0x4e59b44847b379578588920cA78FbF26c0B4956C,
            flags,
            0,
            type(OrderflowDescriminator).creationCode,
            abi.encode(
                address(manager),
                address(0x48Da21ce34966A64E267CeFb78012C0282D0Ac87)
            )
        );

        discriminator = new OrderflowDescriminator{salt: salt}(
            IPoolManager(address(manager)),
            IFtsoRegistry(address(0x48Da21ce34966A64E267CeFb78012C0282D0Ac87))
        );
        require(
            address(discriminator) == hookAddress,
            "CounterTest: hook address mismatch"
        );

        console.log("OrderDiscriminator deployed: ", address(discriminator));

        discriminator.setFee(123);

        // Create the pool as LP
        poolKey = IPoolManager.PoolKey({
            currency0: Currency.wrap(address(token0)),
            currency1: Currency.wrap(address(token1)),
            fee: 3000 | FeeLibrary.DYNAMIC_FEE_FLAG,
            tickSpacing: 60,
            hooks: IHooks(discriminator)
        });

        poolId = poolKey.toId();
        manager.initialize(poolKey, Constants.SQRT_RATIO_1_1900);
        console.log("Liquidity Pool created: Along with beforeInitiale Hook");

        // Provide liquidity to the pool
        modifyPositionRouter.modifyPosition(
            poolKey,
            IPoolManager.ModifyPositionParams(
                TickMath.minUsableTick(60),
                TickMath.maxUsableTick(60),
                10 ether
            )
        );

        vm.stopBroadcast();

        vm.startBroadcast(aSWAPPER);

        //console.log(userSwapCountBefore);
        console.log(aSWAPPER);

        uint256 balanceToken0Before = token0.balanceOf(aSWAPPER);
        uint256 balanceToken1Before = token1.balanceOf(aSWAPPER);

        // Perform a swap
        uint256 amount = 1 ether;
        bool zeroForOne = true;

        swap(poolKey, int256(amount), zeroForOne);
        vm.stopBroadcast();

        vm.startBroadcast(aSWAPPER);
        swap(poolKey, int256(amount), zeroForOne);

        // uint256 balanceToken0After = token0.balanceOf(aSWAPPER);
        // uint256 balanceToken1After = token1.balanceOf(aSWAPPER);

        // console.log("Amount token0 in: %s", amount);

        vm.stopBroadcast();
    }
}
