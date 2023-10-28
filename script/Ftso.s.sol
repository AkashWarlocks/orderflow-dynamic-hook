// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/Script.sol";
import {IFlareContractRegistry} from "@flarenetwork/flare-periphery-contracts/lib/flare-foundry-periphery-package/src/coston/util-contracts/userInterfaces/IFlareContractRegistry.sol";

contract Ftso is Script {
 
    IFlareContractRegistry flareContractRegistry;
    function setUp() public {
    //    flareContractRegistry =  IFlareContractRegistry("0xaD67FE66660Fb8dFE9d6b1b4240d8650e30F6019");
    }

    function run() public {
        
        vm.broadcast();
    }
}
