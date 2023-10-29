// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/Script.sol";
import {Hooks} from "v4-minimal/contracts/libraries/Hooks.sol";
import {IPoolManager} from "v4-minimal/contracts/interfaces/IPoolManager.sol";
import {OrderflowDescriminator} from "../src/OrderflowDescriminator.sol";
import {HookMiner} from "../test/utils/HookMiner.sol";
import {IFtsoRegistry} from "@flarenetwork/flare-periphery-contracts/lib/flare-foundry-periphery-package/src/coston2/ftso/userInterfaces/IFtsoRegistry.sol";
import {Constants} from "./Constants.sol";

contract OrderflowDescriminatorScript is Script {
    address constant CREATE2_DEPLOYER =
        address(0x4e59b44847b379578588920cA78FbF26c0B4956C);

    function setUp() public {}

    function run() public {
        IPoolManager manager = IPoolManager(payable(Constants.POOL_MANAGER));

        // hook contracts must have specific flags encoded in the address
        uint160 flags = uint160(
            Hooks.BEFORE_INITIALIZE_FLAG |
                Hooks.BEFORE_SWAP_FLAG |
                Hooks.AFTER_SWAP_FLAG
        );
        // Create Instance of FtsoRegistry
        IFtsoRegistry _ftsoRegistry = IFtsoRegistry(Constants.FTSO_REGISTRY);
        // Mine a salt that will produce a hook address with the correct flags
        (address hookAddress, bytes32 salt) = HookMiner.find(
            CREATE2_DEPLOYER,
            flags,
            1000,
            type(OrderflowDescriminator).creationCode,
            abi.encode(address(manager), address(_ftsoRegistry))
        );

        // Deploy the hook using CREATE2
        vm.broadcast();
        OrderflowDescriminator hook = new OrderflowDescriminator{salt: salt}(
            manager,
            _ftsoRegistry
        );
        console.log(hookAddress);
        require(address(hook) == hookAddress, "Script: hook address mismatch");
    }
}
