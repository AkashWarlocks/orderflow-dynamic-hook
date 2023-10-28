// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {BaseHook} from "periphery-next/BaseHook.sol";

import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {Hooks} from "v4-core/libraries/Hooks.sol";
import {PoolId, PoolIdLibrary} from "v4-core/types/PoolId.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";

import {BalanceDelta} from "v4-core/types/BalanceDelta.sol";

contract OrderflowDescriminator is BaseHook {
    using PoolIdLibrary for PoolKey;

    uint24 internal fee;

    // Cross-pool user state
    mapping(address user => uint256 swapCount) public globalUserSwapCount;

    /// @dev public for testing
    function setFee(uint24 _fee) public {
        fee = _fee;
    }

    function getFee(
        address,
        PoolKey calldata,
        IPoolManager.SwapParams calldata,
        bytes calldata
    ) public view returns (uint24) {
        return fee;
    }

    constructor(IPoolManager _poolManager) BaseHook(_poolManager) {}

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

    function beforeSwap(
        address,
        PoolKey calldata,
        IPoolManager.SwapParams calldata,
        bytes calldata
    ) external override returns (bytes4) {
        return BaseHook.beforeSwap.selector;
    }

    function afterSwap(
        address swapper,
        PoolKey calldata,
        IPoolManager.SwapParams calldata,
        BalanceDelta,
        bytes calldata
    ) external override returns (bytes4) {
        globalUserSwapCount[swapper]++;
        return BaseHook.afterSwap.selector;
    }
}
