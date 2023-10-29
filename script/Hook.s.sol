// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";

import {PoolManager} from "v4-minimal/contracts/PoolManager.sol";
import {IPoolManager} from "v4-minimal/contracts/interfaces/IPoolManager.sol";
import {PoolKey} from "v4-minimal/contracts/types/PoolKey.sol";
import {PoolModifyPositionTest} from "v4-minimal/test/PoolModifyPositionTest.sol";
import {PoolSwapTest} from "v4-minimal/test/PoolSwapTest.sol";
import {PoolDonateTest} from "v4-minimal/test/PoolDonateTest.sol";

import {TestERC20} from "../test/utils/TestERC20.sol";
import {TickMath} from "v4-minimal/contracts/libraries/TickMath.sol";

/// @notice Contract to initialize some test helpers
/// @dev Minimal initialization. Inheriting contract should set up pools and provision liquidity
contract Hook is Script {
    PoolManager manager;
    PoolModifyPositionTest modifyPositionRouter;
    PoolSwapTest swapRouter;
    PoolDonateTest donateRouter;
    TestERC20 token0;
    TestERC20 token1;

    uint160 public constant MIN_PRICE_LIMIT = TickMath.MIN_SQRT_RATIO + 1;
    uint160 public constant MAX_PRICE_LIMIT = TickMath.MAX_SQRT_RATIO - 1;

    function initHookEnv() public {
        uint256 amount = 2 ** 128;
        TestERC20 _tokenA = new TestERC20("WrappedETH", "testETH", amount);
        TestERC20 _tokenB = new TestERC20("USDC", "testUSDC", amount);

        _tokenA.mint(0xD2203c4bdB029aF733CFF2518F4e7E55cfF0eC49, amount);
        _tokenB.mint(0xD2203c4bdB029aF733CFF2518F4e7E55cfF0eC49, amount);

        _tokenA.mint(0xb8cEF9F8DF86e33eCA46f8650fA03D4847e49775, amount);
        _tokenB.mint(0xb8cEF9F8DF86e33eCA46f8650fA03D4847e49775, amount);

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
        token0.approve(address(modifyPositionRouter), amount);
        token1.approve(address(modifyPositionRouter), amount);
    }

    function swap(
        IPoolManager.PoolKey memory key,
        int256 amountSpecified,
        bool zeroForOne
    ) internal {
        uint256 amount = 2 ** 128;

        token0.approve(address(swapRouter), amount);
        token1.approve(address(swapRouter), amount);

        token0.approve(address(manager), amount);
        token1.approve(address(manager), amount);

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
