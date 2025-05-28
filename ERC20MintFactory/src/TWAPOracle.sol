// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";

contract TWAPOracle is Ownable {
    IUniswapV2Pair public immutable pair;
    address public immutable token0;
    address public immutable token1;
    
    uint public windowSize = 1 hours;
    uint public lastUpdateTime;
    uint public price0CumulativeLast;
    uint public price1CumulativeLast;
    
    constructor(address _pair) Ownable(msg.sender) {
        pair = IUniswapV2Pair(_pair);
        token0 = pair.token0();
        token1 = pair.token1();
        
        (uint reserve0, uint reserve1, uint blockTimestampLast) = IUniswapV2Pair(_pair).getReserves();
        require(reserve0 > 0 && reserve1 > 0, "TWAP: no initial reserves");
        
        price0CumulativeLast = reserve1 * 1e18 / reserve0;
        price1CumulativeLast = reserve0 * 1e18 / reserve1;
        lastUpdateTime = block.timestamp;
    }

    function update() external {
        (uint reserve0, uint reserve1, uint blockTimestampLast) = pair.getReserves();
        require(reserve0 > 0 && reserve1 > 0, "TWAP: no reserves");
        
        // Always update cumulative prices and timestamp
        uint timeElapsed = block.timestamp - lastUpdateTime;
        if (timeElapsed > 0) {
            price0CumulativeLast += reserve1 * 1e18 / reserve0 * timeElapsed;
            price1CumulativeLast += reserve0 * 1e18 / reserve1 * timeElapsed;
        }
        lastUpdateTime = block.timestamp;
    }

    function consult(address token, uint amountIn) external view returns (uint amountOut) {
        (uint reserve0, uint reserve1, ) = pair.getReserves();
        require(reserve0 > 0 && reserve1 > 0, "TWAP: no reserves");
        
        uint timeElapsed = block.timestamp - lastUpdateTime;
        if (timeElapsed == 0) {
            // Return spot price if no time elapsed
            if (token == token0) {
                return amountIn * reserve1 / reserve0;
            } else {
                return amountIn * reserve0 / reserve1;
            }
        }
        
        uint currentPrice0 = reserve1 * 1e18 / reserve0;
        uint currentPrice1 = reserve0 * 1e18 / reserve1;
        
        uint avgPrice0 = (price0CumulativeLast + currentPrice0 * timeElapsed) / timeElapsed;
        uint avgPrice1 = (price1CumulativeLast + currentPrice1 * timeElapsed) / timeElapsed;
        
        if (token == token0) {
            amountOut = amountIn * avgPrice1 / 1e18;
        } else {
            amountOut = amountIn * avgPrice0 / 1e18;
        }
    }

    function setWindowSize(uint _windowSize) external onlyOwner {
        windowSize = _windowSize;
    }
}
