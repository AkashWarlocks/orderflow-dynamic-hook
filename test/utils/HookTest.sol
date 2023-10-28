// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

import {PoolManager} from "v4-minimal/contracts/PoolManager.sol";
import {IPoolManager} from "v4-minimal/contracts/interfaces/IPoolManager.sol";
import {PoolKey} from "v4-minimal/contracts/types/PoolKey.sol";
import {PoolModifyPositionTest} from "v4-minimal/test/PoolModifyPositionTest.sol";
import {PoolSwapTest} from "v4-minimal/test/PoolSwapTest.sol";
import {PoolDonateTest} from "v4-minimal/test/PoolDonateTest.sol";

import {TestERC20} from "v4-minimal/test/TestERC20.sol";
import {TickMath} from "v4-minimal/contracts/libraries/TickMath.sol";

/// @notice Contract to initialize some test helpers
/// @dev Minimal initialization. Inheriting contract should set up pools and provision liquidity
contract HookTest is Test {
    PoolManager manager;
    PoolModifyPositionTest modifyPositionRouter;
    PoolSwapTest swapRouter;
    PoolDonateTest donateRouter;
    TestERC20 token0;
    TestERC20 token1;

    uint160 public constant MIN_PRICE_LIMIT = TickMath.MIN_SQRT_RATIO + 1;
    uint160 public constant MAX_PRICE_LIMIT = TickMath.MAX_SQRT_RATIO - 1;

    function initHookTestEnv() public {
        uint256 amount = 10 ** 20;
        TestERC20 _tokenA = new TestERC20(amount);
        TestERC20 _tokenB = new TestERC20(amount);

        address LP = vm.addr(1);
        _tokenA.mint(LP, amount);
        _tokenB.mint(LP, amount);

        // pools alphabetically sort tokens by address
        // so align `token0` with `pool.token0` for consistency
        if (address(_tokenA) < address(_tokenB)) {
            token0 = _tokenA;
            token1 = _tokenB;
        } else {
            token0 = _tokenB;
            token1 = _tokenA;
        }
        manager = new PoolManager(500000);

        // Helpers for interacting with the pool
        modifyPositionRouter = new PoolModifyPositionTest(
            IPoolManager(address(manager))
        );
        swapRouter = new PoolSwapTest(IPoolManager(address(manager)));
        donateRouter = new PoolDonateTest(IPoolManager(address(manager)));

        // Approve for swapping
        token0.approve(address(swapRouter), amount);
        token1.approve(address(swapRouter), amount);

        // Approve for liquidity provision on LP
        vm.startPrank(LP);
        token0.approve(address(modifyPositionRouter), amount);
        token1.approve(address(modifyPositionRouter), amount);
        vm.stopPrank();
    }

    function swap(
        IPoolManager.PoolKey memory key,
        int256 amountSpecified,
        bool zeroForOne
    ) internal {
        IPoolManager.SwapParams memory params = IPoolManager.SwapParams({
            zeroForOne: zeroForOne,
            amountSpecified: amountSpecified,
            sqrtPriceLimitX96: zeroForOne ? MIN_PRICE_LIMIT : MAX_PRICE_LIMIT // unlimited impact
        });

        PoolSwapTest.TestSettings memory testSettings = PoolSwapTest
            .TestSettings({withdrawTokens: true, settleUsingTransfer: true});

        swapRouter.swap(key, params, testSettings);
    }
}
