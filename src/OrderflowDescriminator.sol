// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {BaseHook} from "v4-minimal/contracts/BaseHook.sol";

import {IPoolManager} from "v4-minimal/contracts/interfaces/IPoolManager.sol";
import {Hooks} from "v4-minimal/contracts/libraries/Hooks.sol";
import {PoolId, PoolIdLibrary} from "v4-minimal/contracts/types/PoolId.sol";
import {PoolKey} from "v4-minimal/contracts/types/PoolKey.sol";
import {FeeLibrary} from "v4-minimal/contracts/libraries/FeeLibrary.sol";

import {BalanceDelta} from "v4-minimal/contracts/types/BalanceDelta.sol";

contract OrderflowDescriminator is BaseHook {
    using PoolIdLibrary for IPoolManager.PoolKey;
    using FeeLibrary for uint24;

    error MustUseDynamicFee();

    uint24 internal fee;

    // Cross-pool user state
    mapping(address user => uint256 swapCount) public globalUserSwapCount;

    /// @dev public for testing
    function setFee(uint24 _fee) public {
        fee = _fee;
    }

    function getFee(
        address,
        IPoolManager.PoolKey memory key,
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

    function beforeInitialize(
        address,
        IPoolManager.PoolKey memory key,
        uint160
    ) external pure override returns (bytes4 selector) {
        if (!key.fee.isDynamicFee()) revert MustUseDynamicFee();
        return BaseHook.beforeInitialize.selector;
    }

    function beforeSwap(
        address,
        IPoolManager.PoolKey memory key,
        IPoolManager.SwapParams calldata
    ) external override returns (bytes4) {
        return BaseHook.beforeSwap.selector;
    }

    function afterSwap(
        address swapper,
        IPoolManager.PoolKey memory key,
        IPoolManager.SwapParams calldata,
        BalanceDelta
    ) external override returns (bytes4) {
        globalUserSwapCount[swapper]++;
        return BaseHook.afterSwap.selector;
    }
}
