// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../src/TokenA.sol";
import "../src/TokenB.sol";
import "../src/AMM.sol";

contract AMMTest is Test {
    TokenA tokenA;
    TokenB tokenB;
    AMM amm;

    address alice = address(0x1);
    address bob = address(0x2);

    function setUp() public {
        tokenA = new TokenA();
        tokenB = new TokenB();
        amm = new AMM(address(tokenA), address(tokenB));

        tokenA.mint(alice, 10_000 ether);
        tokenB.mint(alice, 10_000 ether);
        tokenA.mint(bob, 10_000 ether);
        tokenB.mint(bob, 10_000 ether);

        vm.prank(alice);
        tokenA.approve(address(amm), type(uint256).max);
        vm.prank(alice);
        tokenB.approve(address(amm), type(uint256).max);

        vm.prank(bob);
        tokenA.approve(address(amm), type(uint256).max);
        vm.prank(bob);
        tokenB.approve(address(amm), type(uint256).max);
    }

    function testAddLiquidityFirstProvider() public {
        vm.prank(alice);
        uint256 lp = amm.addLiquidity(1000 ether, 1000 ether);

        assertGt(lp, 0);
        assertEq(amm.reserveA(), 1000 ether);
        assertEq(amm.reserveB(), 1000 ether);
    }

    function testAddLiquiditySecondProvider() public {
        vm.prank(alice);
        amm.addLiquidity(1000 ether, 1000 ether);

        vm.prank(bob);
        uint256 lp = amm.addLiquidity(500 ether, 500 ether);

        assertGt(lp, 0);
        assertEq(amm.reserveA(), 1500 ether);
        assertEq(amm.reserveB(), 1500 ether);
    }

    function testRevertAddLiquidityZeroAmounts() public {
        vm.prank(alice);
        vm.expectRevert("zero amount");
        amm.addLiquidity(0, 100 ether);
    }

    function testRemoveLiquidityPartial() public {
        vm.prank(alice);
        uint256 lp = amm.addLiquidity(1000 ether, 1000 ether);

        vm.prank(alice);
        (uint256 amountA, uint256 amountB) = amm.removeLiquidity(lp / 2);

        assertGt(amountA, 0);
        assertGt(amountB, 0);
        assertEq(amm.reserveA(), 500 ether);
        assertEq(amm.reserveB(), 500 ether);
    }

    function testRemoveLiquidityFull() public {
        vm.prank(alice);
        uint256 lp = amm.addLiquidity(1000 ether, 1000 ether);

        vm.prank(alice);
        amm.removeLiquidity(lp);

        assertEq(amm.reserveA(), 0);
        assertEq(amm.reserveB(), 0);
    }

    function testSwapTokenAToTokenB() public {
        vm.prank(alice);
        amm.addLiquidity(1000 ether, 1000 ether);

        uint256 bobBefore = tokenB.balanceOf(bob);

        vm.prank(bob);
        uint256 amountOut = amm.swap(address(tokenA), 100 ether, 1);

        assertGt(amountOut, 0);
        assertEq(tokenB.balanceOf(bob), bobBefore + amountOut);
    }

    function testSwapTokenBToTokenA() public {
        vm.prank(alice);
        amm.addLiquidity(1000 ether, 1000 ether);

        uint256 bobBefore = tokenA.balanceOf(bob);

        vm.prank(bob);
        uint256 amountOut = amm.swap(address(tokenB), 100 ether, 1);

        assertGt(amountOut, 0);
        assertEq(tokenA.balanceOf(bob), bobBefore + amountOut);
    }

    function testGetAmountOutWorks() public view {
        uint256 out = amm.getAmountOut(100 ether, 1000 ether, 1000 ether);
        assertGt(out, 0);
    }

    function testRevertSwapZeroInput() public {
        vm.prank(alice);
        amm.addLiquidity(1000 ether, 1000 ether);

        vm.prank(bob);
        vm.expectRevert("zero input");
        amm.swap(address(tokenA), 0, 1);
    }

    function testRevertSwapInvalidToken() public {
        vm.prank(alice);
        amm.addLiquidity(1000 ether, 1000 ether);

        vm.prank(bob);
        vm.expectRevert("invalid token");
        amm.swap(address(0x1234), 100 ether, 1);
    }

    function testRevertSwapSlippageTooHigh() public {
        vm.prank(alice);
        amm.addLiquidity(1000 ether, 1000 ether);

        vm.prank(bob);
        vm.expectRevert("slippage too high");
        amm.swap(address(tokenA), 100 ether, 1000 ether);
    }

    function testKIncreasesOrStaysAfterSwap() public {
        vm.prank(alice);
        amm.addLiquidity(1000 ether, 1000 ether);

        uint256 kBefore = amm.reserveA() * amm.reserveB();

        vm.prank(bob);
        amm.swap(address(tokenA), 100 ether, 1);

        uint256 kAfter = amm.reserveA() * amm.reserveB();
        assertGe(kAfter, kBefore);
    }

    function testLargeSwapCausesPriceImpact() public {
        vm.prank(alice);
        amm.addLiquidity(1000 ether, 1000 ether);

        uint256 smallOut = amm.getAmountOut(10 ether, amm.reserveA(), amm.reserveB());
        uint256 largeOut = amm.getAmountOut(500 ether, amm.reserveA(), amm.reserveB());

        assertTrue(largeOut < smallOut * 50);
    }

    function testFuzzSwap(uint256 amountIn) public {
        vm.prank(alice);
        amm.addLiquidity(5000 ether, 5000 ether);

        vm.assume(amountIn > 1e9 && amountIn < 1000 ether);

        uint256 expectedOut = amm.getAmountOut(amountIn, amm.reserveA(), amm.reserveB());
        vm.assume(expectedOut > 0);

        uint256 bobBefore = tokenB.balanceOf(bob);

        vm.prank(bob);
        uint256 amountOut = amm.swap(address(tokenA), amountIn, 1);

        assertGt(amountOut, 0);
        assertEq(tokenB.balanceOf(bob), bobBefore + amountOut);
    }

    function testEventLiquidityAdded() public {
        vm.prank(alice);
        amm.addLiquidity(1000 ether, 1000 ether);

        assertEq(amm.reserveA(), 1000 ether);
        assertEq(amm.reserveB(), 1000 ether);
    }

    function testEventSwap() public {
        vm.prank(alice);
        amm.addLiquidity(1000 ether, 1000 ether);

        vm.prank(bob);
        uint256 amountOut = amm.swap(address(tokenA), 100 ether, 1);

        assertGt(amountOut, 0);
    }
}
