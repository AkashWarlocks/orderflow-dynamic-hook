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

    // Fee in BPS
    uint24 public constant BASE_FEE = 3000;
    uint24 internal _fee;

    struct User {
        uint256 positiveSwapCount;
        uint256 toxicSwapCount;
        uint256 transactionFrequency;
        uint256 totalValueTraded;
    }

    // Cross-pool user state
    mapping(address => User) public users;

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

        (
            uint256 oracleToken1PriceUSD,
            ,
            uint256 quoteDecimalsToken1
        ) = _ftsoRegistry.getCurrentPriceWithDecimals(
                tokenAddressSymbol[address1]
            );
        uint256 oracleToken1PriceDecimalAdjusted = oracleToken1PriceUSD *
            10 ** (18 - quoteDecimalsToken1);

        uint256 priceDiff = 0;
        if (swapParams_.zeroForOne == true) {
            uint256 onChainToken0PriceUSD = ((oracleToken1PriceDecimalAdjusted *
                (1 * 10 ** 18)) / priceBeforeSwap);
            console.log(
                "Token 0 in USD through token 1 %s",
                onChainToken0PriceUSD
            );

            console.log(
                "Token 0 in USD by oracle %s",
                oracleToken0PriceDecimalAdjusted
            );

            if (onChainToken0PriceUSD > oracleToken0PriceDecimalAdjusted) {
                priceDiff =
                    onChainToken0PriceUSD -
                    oracleToken0PriceDecimalAdjusted;
            }
        } else {
            uint256 onChainToken1PriceUSD = (oracleToken0PriceDecimalAdjusted *
                priceBeforeSwap) / (10 ** 18);
            console.log(
                "Token 1 in USD through token 0 %s",
                onChainToken1PriceUSD
            );

            console.log(
                "Token 1 in USD by oracle %s",
                oracleToken1PriceDecimalAdjusted
            );
            if (onChainToken1PriceUSD > oracleToken1PriceDecimalAdjusted) {
                priceDiff =
                    onChainToken1PriceUSD -
                    oracleToken1PriceDecimalAdjusted;
            }

            address userAddress = tx.origin;
            uint256 userFee = getFeeForUser(userAddress);
            User storage user = users[userAddress];

            // Check if arb would be profitable after fees for user
            // TODO: This shuold check the pricediff in bps, not absoloute difference
            if (priceDiff > userFee) {
                console.log("Toxic transaction detected");
                user.toxicSwapCount++;
            } else {
                console.log("Non-toxic transaction");
                user.positiveSwapCount++;
            }
            uint24 updatedUserFee = getFeeForUser(userAddress);

            uint24 fee = updatedUserFee;
            console.log("Fee charged to user: %s. Base fee is 3000 ", fee);
            setFee(fee);
        }

        return BaseHook.beforeSwap.selector;
    }

    function afterSwap(
        address swapper,
        IPoolManager.PoolKey memory key,
        IPoolManager.SwapParams calldata,
        BalanceDelta
    ) external override returns (bytes4) {
        users[tx.origin].positiveSwapCount += 1;
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

    function _getFeeAmplifier(
        User memory user_
    ) internal pure returns (int256) {
        int256 feeAmplifier = 0;

        // Calculate the ratio of toxic swaps to total swaps
        uint256 totalSwaps = user_.toxicSwapCount + user_.positiveSwapCount;
        if (totalSwaps > 0) {
            uint256 toxicRatio = (user_.toxicSwapCount * 1000) / totalSwaps; // Multiplied by 1000 for precision
            feeAmplifier += int256(toxicRatio) - 500; // Subtracting 500 to center around 0
        }

        return feeAmplifier;
    }

    function getFeeForUser(address user_) public view returns (uint24) {
        User memory user = users[user_];
        int256 amplifier = _getFeeAmplifier(user);

        // for demo purposes
        if (amplifier > 0) {
            return uint24(6000);
        } else {
            return uint24(1000);
        }
        // int256 fee = BASE_FEE + amplifier;

        // // minimum fee: 10 bps (0.1%)
        // if (fee < 100) fee = 100;

        // return uint256(fee);
    }
}
