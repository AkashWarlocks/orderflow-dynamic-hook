// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {BaseHook} from "v4-minimal/contracts/BaseHook.sol";

import {FullMath} from "@uniswap/v4-core/contracts/libraries/FullMath.sol";

import {IPoolManager} from "v4-minimal/contracts/interfaces/IPoolManager.sol";
import {Hooks} from "v4-minimal/contracts/libraries/Hooks.sol";
import {PoolId, PoolIdLibrary} from "v4-minimal/contracts/libraries/PoolId.sol";
import {PoolKey} from "v4-minimal/contracts/types/PoolKey.sol";
import {FeeLibrary} from "v4-minimal/contracts/libraries/FeeLibrary.sol";
import {BalanceDelta} from "v4-minimal/contracts/types/BalanceDelta.sol";
import {SqrtPriceMath} from "@uniswap/v4-core/contracts/libraries/SqrtPriceMath.sol";
import {SwapMath} from "@uniswap/v4-core/contracts/libraries/SwapMath.sol";
import {CurrencyLibrary, Currency} from "v4-minimal/contracts/libraries/CurrencyLibrary.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IFtsoRegistry} from "@flarenetwork/flare-periphery-contracts/lib/flare-foundry-periphery-package/src/coston2/ftso/userInterfaces/IFtsoRegistry.sol";
//import {FtsoRegistry} from "@flarenetwork/flare-periphery-contracts/lib/flare-foundry-periphery-package/src/coston2/ftso/FtsoRegistry.sol";

import "forge-std/console.sol";

contract OrderflowDescriminator is BaseHook {
    using PoolIdLibrary for IPoolManager.PoolKey;
    using FeeLibrary for uint24;

    mapping(address => string) private tokenAddressSymbol;

    IFtsoRegistry internal _ftsoRegistry;
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
        IPoolManager.PoolKey memory key
    ) public view returns (uint24) {
        return _fee;
    }

    constructor(
        IPoolManager poolManager_,
        IFtsoRegistry ftsoRegistryAddress_
    ) BaseHook(poolManager) {
        _poolManager = poolManager_;
        _ftsoRegistry = ftsoRegistryAddress_;
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
    ) external override returns (bytes4 selector) {
        if (!key_.fee.isDynamicFee()) revert MustUseDynamicFee();
        // Get Currency0 and Currency1
        address address0 = Currency.unwrap(key_.currency0);
        address address1 = Currency.unwrap(key_.currency1);

        ERC20 token0 = ERC20(address0);
        ERC20 token1 = ERC20(address1);

        // Get Symbol
        string memory symbol0 = token0.symbol();
        string memory symbol1 = token1.symbol();

        tokenAddressSymbol[address0] = symbol0;
        tokenAddressSymbol[address1] = symbol1;

        return BaseHook.beforeInitialize.selector;
    }

    function beforeSwap(
        address,
        IPoolManager.PoolKey memory poolKey_,
        IPoolManager.SwapParams calldata swapParams_
    ) external override returns (bytes4) {
        PoolId poolId = PoolIdLibrary.toId(poolKey_);
        uint128 liquidity = _poolManager.getLiquidity(poolId);

        (uint160 currentSqrtPriceX96, , , , , ) = _poolManager.getSlot0(
            PoolIdLibrary.toId(poolKey_)
        );

        console.log("sqrt price current %s", currentSqrtPriceX96);

        // uint160 sqrtPriceX96After = SqrtPriceMath
        //     .getNextSqrtPriceFromAmount0RoundingUp(
        //         currentSqrtPriceX96,
        //         liquidity,
        //         uint256(swapParams_.amountSpecified),
        //         swapParams_.zeroForOne
        //     );

        uint256 priceBeforeSwap = _sqrtPriceX96ToUint(currentSqrtPriceX96, 18);
        console.log("Current pool price %s", priceBeforeSwap);

        address address0 = Currency.unwrap(poolKey_.currency0);
        address address1 = Currency.unwrap(poolKey_.currency1);

        (
            uint256 oracleToken0PriceUSD,
            ,
            uint256 quoteDecimalsToken0
        ) = _ftsoRegistry.getCurrentPriceWithDecimals(
                tokenAddressSymbol[address0]
            );
        uint256 oracleToken0PriceDecimalAdjusted = oracleToken0PriceUSD *
            10 ** (18 - quoteDecimalsToken0);

        uint256 onChainToken1PriceUSD = (oracleToken0PriceDecimalAdjusted *
            priceBeforeSwap) / (10 ** 18);

        console.log("Token 1 in USD through token 0 %s", onChainToken1PriceUSD);
        (
            uint256 oracleToken1PriceUSD,
            ,
            uint256 quoteDecimalsToken1
        ) = _ftsoRegistry.getCurrentPriceWithDecimals(
                tokenAddressSymbol[address1]
            );
        uint256 oracleToken1PriceDecimalAdjusted = oracleToken1PriceUSD *
            10 ** (18 - quoteDecimalsToken1);

        console.log(tokenAddressSymbol[address1]);
        console.log(
            "Token 1 in USD by oracle %s",
            oracleToken1PriceDecimalAdjusted
        );

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

    function _sqrtPriceX96ToUint(
        uint160 sqrtPriceX96,
        uint8 decimalsToken0
    ) internal pure returns (uint256) {
        uint256 numerator1 = uint256(sqrtPriceX96) * uint256(sqrtPriceX96);
        uint256 numerator2 = 10 ** decimalsToken0;
        return FullMath.mulDiv(numerator1, numerator2, 1 << 192);
    }
}
