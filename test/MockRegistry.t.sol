pragma solidity ^0.8.20;

// Foundry libraries
import "forge-std/Test.sol";
import "forge-std/console.sol";
import {GasSnapshot} from "forge-gas-snapshot/GasSnapshot.sol";

//Flare-libs
import {MockFtsoRegistry} from "@flarenetwork/flare-periphery-contracts/lib/flare-foundry-periphery-package/src/coston2/mockContracts/MockFtsoRegistry.sol";
import {MockFtso} from "@flarenetwork/flare-periphery-contracts/lib/flare-foundry-periphery-package/src/coston2/mockContracts/MockFtso.sol";

contract MockRegistry is Test {
    MockFtsoRegistry mockFtsoRegistry;
    MockFtso mockFtso;

    function setUp() public {
        mockFtso = new MockFtso("ETH", 5);
        mockFtsoRegistry = new MockFtsoRegistry();
    }

    function testAddMockFtso() public {
        uint256 index = mockFtsoRegistry.addFtso(mockFtso);
        assertEq(0, index, "Invalid Index");
    }

    function testSetCurrentPriceForSymbol() public {
        uint256 timestamp = block.timestamp;
        mockFtsoRegistry.setPriceForSymbol("ETH", 1000, timestamp, 5);
        (
            uint256 _price,
            uint256 _timestamp,
            uint256 _assetPriceUsdDecimals
        ) = mockFtsoRegistry.getCurrentPriceWithDecimals("ETH");

        assertEq(1000, _price, "Invalid Price");
        assertEq(timestamp, _timestamp, "Invalid timestamp");
        assertEq(5, _assetPriceUsdDecimals, "Invalid Decimals");
    }
}
