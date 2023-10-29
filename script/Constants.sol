pragma solidity ^0.8.20;
import {TickMath} from "v4-minimal/contracts/libraries/TickMath.sol";

library Constants {
    address public constant POOL_MANAGER =
        0x0fFBB73237E482Ee4c03bdb3E80638F4F9566b59;
    address public constant FTSO_REGISTRY =
        0x48Da21ce34966A64E267CeFb78012C0282D0Ac87;
    address public constant token0 = 0x9A579FF516Bf17388febBD23BCe8C4a42Fb04FAe;
    address public constant token1 = 0xEAcff440306f41B9AD86eD39F03E67ba95bc9490;
    address public constant USER = 0xb8cEF9F8DF86e33eCA46f8650fA03D4847e49775;
    address public constant DISCRIMINATOR_HOOK =
        0x8c12be7B669E3B7431f1a03aF402Dfe93b8205eE;

    uint160 public constant SQRT_ETHUSDC_1778 =
        1879202667322918815191717338715882;
    uint160 public constant MIN_PRICE_LIMIT = TickMath.MIN_SQRT_RATIO + 1;
    uint160 public constant MAX_PRICE_LIMIT = TickMath.MAX_SQRT_RATIO - 1;
    uint160 public constant SQRT_RATIO_1_1 = 79228162514264337593543950336;
}
