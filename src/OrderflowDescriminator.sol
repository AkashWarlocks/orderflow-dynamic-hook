// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {BaseHook} from "v4-minimal/contracts/BaseHook.sol";

import {FullMath} from "@uniswap/v4-core/contracts/libraries/FullMath.sol";

import {IPoolManager} from "v4-minimal/contracts/interfaces/IPoolManager.sol";
import {Hooks} from "v4-minimal/contracts/libraries/Hooks.sol";
import {PoolId, PoolIdLibrary} from "v4-minimal/contracts/types/PoolId.sol";
import {PoolKey} from "v4-minimal/contracts/types/PoolKey.sol";
import {FeeLibrary} from "v4-minimal/contracts/libraries/FeeLibrary.sol";
import {BalanceDelta} from "v4-minimal/contracts/types/BalanceDelta.sol";
import {SqrtPriceMath} from "@uniswap/v4-core/contracts/libraries/SqrtPriceMath.sol";

import "forge-std/console.sol";

contract OrderflowDescriminator is BaseHook {
    using PoolIdLibrary for IPoolManager.PoolKey;
    using FeeLibrary for uint24;

    IPoolManager internal _poolManager;
    error MustUseDynamicFee();

    uint24 internal _fee;

    // Cross-pool user state
    mapping(address user => uint256 swapCount) public globalUserSwapCount;

    /// @dev public for testing
    function setFee(uint24 fee_) public {
        _fee = fee_;
    }

    function getFee(
        address,
        IPoolManager.PoolKey memory key,
        IPoolManager.SwapParams calldata,
        bytes calldata
    ) public view returns (uint24) {
        return _fee;
    }

    constructor(IPoolManager poolManager_) BaseHook(poolManager) {
        _poolManager = poolManager_;
    }

    function getHooksCalls() public pure override returns (Hooks.Calls memory) {
        return
            Hooks.Calls({
                beforeInitialize: true,
                afterInitialize: false,
                beforeModifyPosition: false,
                afterModifyPosition: false,
                beforeSwap: true,
                afterSwap: true,
                beforeDonate: false,
                afterDonate: false
            });
    }

    // -----------------------------------------------
    // NOTE: see IHooks.sol for function documentation
    // -----------------------------------------------

    function beforeInitialize(
        address,
        IPoolManager.PoolKey memory key_,
        uint160
    ) external pure override returns (bytes4 selector) {
        if (!key_.fee.isDynamicFee()) revert MustUseDynamicFee();
        return BaseHook.beforeInitialize.selector;
    }

    function beforeSwap(
        address,
        IPoolManager.PoolKey memory poolKey_,
        IPoolManager.SwapParams calldata swapParams_
    ) external override returns (bytes4) {
        // PoolId poolId = PoolIdLibrary.toId(poolKey_);
        // uint128 liquidity = _poolManager.getLiquidity(poolId);

        // (uint160 sqrtPriceX96, , , , , ) = _poolManager.getSlot0(
        //     PoolIdLibrary.toId(poolKey_)
        // );

        // uint160 nextSqrtPriceX96 = SqrtPriceMath
        //     .getNextSqrtPriceFromAmount0RoundingUp(
        //         sqrtPriceX96,
        //         liquidity,
        //         uint256(swapParams_.amountSpecified),
        //         swapParams_.zeroForOne
        //     );

        // uint256 priceBeforeSwap = _getPrice(sqrtPriceX96);
        // uint256 priceAfterSwap = _getPrice(nextSqrtPriceX96);

        // console.log(priceBeforeSwap);
        // console.log(priceAfterSwap);
        // console.log();

        return BaseHook.beforeSwap.selector;
    }

    function afterSwap(
        address swapper,
        IPoolManager.PoolKey memory key,
        IPoolManager.SwapParams calldata,
        BalanceDelta
    ) external override returns (bytes4) {
        globalUserSwapCount[tx.origin] += 1;
        return BaseHook.afterSwap.selector;
    }

    function _getPrice(
        uint160 sqrtPriceX96_
    ) internal pure returns (uint256 price) {
        price = FullMath.mulDiv(sqrtPriceX96_, sqrtPriceX96_, 2 ** 96);
    }
}
