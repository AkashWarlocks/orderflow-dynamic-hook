### Mayk - Uniswap v4 hook to dynamically adjust fees in reponse to order toxicity

Inspired by: 

[Discrimination of Toxic Flow in Uniswap V3: Part 1](https://crocswap.medium.com/discrimination-of-toxic-flow-in-uniswap-v3-part-1-fb5b6e01398b) 

[Discrimination of Toxic Flow in Uniswap V3: Part 2](https://crocswap.medium.com/discrimination-of-toxic-flow-in-uniswap-v3-part-2-21d84aaa33f5) 

[Discrimination of Toxic Flow in Uniswap V3: Part 3](https://crocswap.medium.com/discrimination-of-toxic-flow-in-uniswap-v3-part-3-4afb386311c0)


## Description
# 1. What is Toxic Flow
"Order flow is regarded as toxic when it adversely selects market makers who may be unaware that they are providing liquidity at a loss."
In defi this typically looks as follows: LPs passively provide liquidity in a liquidity pool, and cex-dex arbitrage bots trade this liquidity against up-to-date centralized venues like Binance. On paper this may not seem like much of an issue, LPs receive trade volume on their pools and earn fees, and users get better price execution. In truth however, whenever arbitrage bot executes a dex arbitrage against your liquidity, the price difference is bigger than the fee generated. When this happens you would always be better off simply keeping your assets in a wallet.
For example, say you provide 1 eth and 1000 usdc into a basic v2 pool and the market price is $1000 / eth. If the price on binance moves 5% and the pool stays flat, an arbitrage bot will swoop in and give you usdc at the rate of ~1000 per eth, and you give up some of your eth which is $1005. You did generate some fees (say 0.3%), but even still your assets will overall be worth less than the $2005 they should be. This is not the same as impermanent loss, and even if markets move back down, if all orderflow is toxic, the value of your assets will continously incur losses. This can be problematic on smaller chains where you want to bootstrap liquidity but the vast majority of trading activiy comes from toxic arbitrage bots.

Market making is not as simple as maximining volume and fees, we need to make sure that our orderflow is more positive/organic, and outweighs the toxic orderflow.
A similar dynamic exists in CeFi, and market makers are able to adjust dynamic spreads on orderbooks. In defi however, fees have been static due to the way dex's are designed. Until now, with uniswap v4 hooks.

# 2. Our v4 hook.
We have created a Uniswap v4 hook OrderflowDiscriminator that dynamically adjusts swap fees in response to a number of indicators of toxicity. We have taken some inspiration for the articles listed above and recommend giving them a read for more context. We've integrated flare's FTSO price feed with the hook, and with every swap, the beforeSwap callback uses oracle data to compute price deviations and detect toxic transactions that would incur a loss greater than the fee generated. In such cases we increase the fee accordingly to a reasonable extent. The goal is not too elimate all toxic flow, there is need for arbitrage, but this way we can limit the losses of LPs and make liquidity providing significantly more efficient - leading improved provision across markets.

The hook will be used my multiple pools, and we keep track of each users swaps across pools. We keep track of how many toxic/non-toxic trades they execute. A high frequency of trades and high ratio of toxic to non-toxic will lead to an increase on top of the default pool fee of 0.3%. We also encourage positive flow by lowering fees who show the opposite characterstics. The need for this dynamic is already made evident by examples like Balancer partnering with CowSwap to offer lower fees to the solvers as it is a large source of organic order-flow. (Just users wanting to go from one asset to another, not well informed arb bots):
https://snapshot.org/#/balancer.eth/proposal/0xd991e9f3c6edd148bd37c600d7ada3d28db1758e3cfd703c02d290f502906f05


The script MainDeploy deploys everything and executes a swap with the hook active.
Tests demo a toxic/positive trade and fee respones from the hook.


## Deployed addresses
| Action      | Contract                                  | Address                                   | Transaction Hash                                                           |
|-------------|-------------------------------------------|-------------------------------------------|---------------------------------------------------------------------------|
| Deploy      | Pool Manager                              | 0x22b8142D0BFfc5Ff3b9976dc3eb44e44866F00e4 | 0xfeb26ea0ca2f0ba72466eb829b92e356eb5b11486f01b024fa63840c1daa7a54 |
| Deploy      | OrderDiscriminator Hook                   | 0x8ced766b88384EA3001D9744A0bcEFFb10B8159e | 0x8e0ef2b58a658f60807b504965e487bdc70d428fbcdb92c03e1446661b378cdb |



-- Caveats: 

Currently the FTSOs update irregularly. We assume that they will be updated reqularly in the future and the hook will rely on other indicators beyond just the oracle price to pool price difference.

This will incur more gas costs on swaps, the v4 singleton poolmanager does offer significant gas optimizations however

