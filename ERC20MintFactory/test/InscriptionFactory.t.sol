// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/InscriptionFactory.sol";
import "../src/InscriptionToken.sol";

contract MockUniswapPair {
    function getReserves() external pure returns (uint112, uint112, uint32) {
        return (100 ether, 200 ether, 0);
    }
    function token0() external pure returns (address) {
        return address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2); // WETH
    }
    function token1() external pure returns (address) {
        return address(0x0000000000000000000000000000000000000001); // TEST
    }
}

contract MockUniswapRouter {
    event LiquidityAdded(
        address token,
        uint amountToken,
        uint amountETH,
        address to
    );

    mapping(address => uint) public tokenBalances;

    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external payable returns (uint, uint, uint) {
        // Simulate token transfer
        IERC20(token).transferFrom(msg.sender, address(this), amountTokenDesired);
        tokenBalances[token] += amountTokenDesired;

        emit LiquidityAdded(
            token,
            amountTokenDesired,
            msg.value,
            to
        );
        return (amountTokenDesired, msg.value, block.timestamp);
    }

    // Add fallback function to accept ETH
    receive() external payable {}

    function getAmountsOut(uint amountIn, address[] calldata path) 
        external pure returns (uint[] memory amounts) 
    {
        amounts = new uint[](2);
        amounts[0] = amountIn;
        amounts[1] = amountIn * 9 / 10; // 90% of input as mock price
    }

    function WETH() external view returns (address) {
        return address(this); // Return mock router address as WETH for testing
    }
}

contract InscriptionFactoryTest is Test {
    InscriptionFactory public factory;
    address public owner = address(1);
    address public user = address(2);
    address public feeRecipient = address(999);
    address public uniswapRouter;
    
    // Add receive function to accept ETH transfers
    receive() external payable {}

    function setUp() public {
        // Deploy mock Uniswap router
        uniswapRouter = address(new MockUniswapRouter());
        
        vm.prank(owner);
        factory = new InscriptionFactory(feeRecipient, uniswapRouter);
        
        // Fund the factory with some ETH for testing
        vm.deal(address(factory), 100 ether);
        
        // Mock user address to accept ETH transfers
        vm.deal(user, 100 ether);
        
        // Enable debug logging
        vm.recordLogs();
    }

    function testDeployInscription() public {
        vm.prank(user);
        address mockPair = address(new MockUniswapPair());
        address tokenAddr = factory.deployInscription("TEST", 1000, 10, 1 ether, mockPair);

        InscriptionToken token = InscriptionToken(tokenAddr);
        assertEq(token.symbol(), "TEST");
        assertEq(token.name(), "Inscription TEST");
        assertEq(token.maxSupply(), 1000);
        assertEq(token.perMint(), 10);
        assertEq(token.price(), 1 ether);
    }

    function testMintInscription() public {
        vm.prank(user);
        address mockPair = address(new MockUniswapPair());
        address tokenAddr = factory.deployInscription("TEST", 1000, 10, 1 ether, mockPair);
        
        uint256 cost = 1 ether * 10;
        vm.deal(user, cost * 2);
        
        // Mock token approval for Uniswap router
        vm.mockCall(
            tokenAddr,
            abi.encodeWithSelector(IERC20.approve.selector, uniswapRouter, 10),
            abi.encode(true)
        );
        
        vm.prank(user);
        factory.mintInscription{value: cost}(tokenAddr);

        InscriptionToken token = InscriptionToken(tokenAddr);
        assertEq(token.balanceOf(user), 10);
    }

    function testLiquidityAdded() public {
        vm.prank(user);
        address mockPair = address(new MockUniswapPair());
        address tokenAddr = factory.deployInscription("TEST", 1000, 10, 1 ether, mockPair);
        
        uint256 cost = 1 ether * 10;
        vm.deal(user, cost * 2);
        
        // Record events
        vm.recordLogs();
        
        vm.prank(user);
        factory.mintInscription{value: cost}(tokenAddr);
        
        // Verify token balance
        InscriptionToken token = InscriptionToken(tokenAddr);
        assertEq(token.balanceOf(user), 10);
        
        // Verify liquidity event was emitted
        Vm.Log[] memory entries = vm.getRecordedLogs();
        assertEq(entries.length, 2); // TokenDeployed and LiquidityAdded
        
        // Check LiquidityAdded event
        Vm.Log memory liquidityEvent = entries[1];
        assertEq(liquidityEvent.emitter, uniswapRouter);
        assertEq(liquidityEvent.topics[0], keccak256("LiquidityAdded(address,uint256,uint256,address)"));
    }

    function testBuyMeme() public {
        vm.prank(user);
        address mockPair = address(new MockUniswapPair());
        address tokenAddr = factory.deployInscription("TEST", 1000, 10, 1 ether, mockPair);
        
        uint256 cost = 1 ether * 10;
        vm.deal(user, cost);
        
        vm.prank(user);
        factory.buyMeme{value: cost}(tokenAddr);
        
        InscriptionToken token = InscriptionToken(tokenAddr);
        assertEq(token.balanceOf(user), 10);
    }

    function testMaxSupply() public {
        vm.prank(user);
        address mockPair = address(new MockUniswapPair());
        address tokenAddr = factory.deployInscription("TEST", 100, 10, 1 ether, mockPair);
        
        uint256 cost = 1 ether * 10;
        vm.deal(user, cost * 10); // Only need enough for 9 mints (90 tokens) since initial deploy may mint
        
        // Should be able to mint 9 times (90 tokens) without hitting max supply
        for (uint i = 0; i < 9; i++) {
            vm.prank(user);
            factory.mintInscription{value: cost}(tokenAddr);
        }
        
        // Next mint should exceed max supply of 100
        vm.expectRevert("Exceeds max supply");
        vm.prank(user);
        factory.mintInscription{value: cost}(tokenAddr);
    }
}
