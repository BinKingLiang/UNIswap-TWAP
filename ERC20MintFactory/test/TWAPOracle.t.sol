// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/TWAPOracle.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";

contract MockUniswapPair {
    address public constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address public constant TEST_TOKEN = 0x0000000000000000000000000000000000000001;
    
    uint public price0CumulativeLast;
    uint public price1CumulativeLast;
    
    function getReserves() external pure returns (uint112, uint112, uint32) {
        return (100 ether, 200 ether, 0);
    }
    
    function token0() external pure returns (address) {
        return WETH;
    }
    
    function token1() external pure returns (address) {
        return TEST_TOKEN;
    }
    
    // Helper to set cumulative prices for testing
    function setCumulativePrices(uint _price0, uint _price1) external {
        price0CumulativeLast = _price0;
        price1CumulativeLast = _price1;
    }
}

contract TWAPOracleTest is Test {
    TWAPOracle public twapOracle;
    IUniswapV2Pair public pair;
    
    function setUp() public {
        // Deploy a mock Uniswap pair with token0 and token1
        pair = IUniswapV2Pair(address(new MockUniswapPair()));
        
        // Deploy TWAPOracle
        twapOracle = new TWAPOracle(address(pair));
        
        // Move time forward at least 1 second to ensure initial time elapsed
        vm.warp(block.timestamp + 1);
    }

    function testBasicPriceCalculation() public {
        // Initial setup with time advance
        vm.warp(block.timestamp + 1 hours);
        
        // First update with reserves 1 : 2 (price 2.0)
        vm.mockCall(
            address(pair),
            abi.encodeWithSelector(IUniswapV2Pair.getReserves.selector),
            abi.encode(1 ether, 2 ether, 0)
        );
        twapOracle.update();
        
        // Move forward 1 hour
        vm.warp(block.timestamp + 1 hours);
        
        // Second update with same reserves
        vm.mockCall(
            address(pair),
            abi.encodeWithSelector(IUniswapV2Pair.getReserves.selector),
            abi.encode(1 ether, 2 ether, 0)
        );
        twapOracle.update();
        
        // Consult price for 1 token0 should be 2 token1
        uint256 amountOut = twapOracle.consult(address(pair.token0()), 1 ether);
        assertEq(amountOut, 2 ether);
    }

    function testMultipleUpdates() public {
        // Initial update
        vm.mockCall(
            address(pair),
            abi.encodeWithSelector(IUniswapV2Pair.getReserves.selector),
            abi.encode(100 ether, 100 ether, 0)
        );
        twapOracle.update();
        
        // Update every hour for 24 hours
        for (uint i = 1; i <= 24; i++) {
            vm.warp(block.timestamp + 1 hours);
            vm.mockCall(
                address(pair),
                abi.encodeWithSelector(IUniswapV2Pair.getReserves.selector),
                abi.encode(100 ether, 100 ether * i, 0)
            );
            twapOracle.update();
        }
        
        // Consult TWAP price (average of 1..24 = 12.5)
        uint256 amountOut = twapOracle.consult(address(pair.token1()), 1 ether);
        assertEq(amountOut, 12.5 ether);
    }
}
