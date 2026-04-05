// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../src/LendingPool.sol";
import "../src/TokenA.sol";
import "../src/TokenB.sol";

contract LendingPoolTest is Test {
    LendingPool pool;
    TokenA collateral;
    TokenB borrowToken;

    address alice = address(0x1);
    address bob = address(0x2);

    function setUp() public {
        collateral = new TokenA();
        borrowToken = new TokenB();

        pool = new LendingPool(address(collateral), address(borrowToken));

        collateral.mint(alice, 10_000 ether);
        borrowToken.mint(address(pool), 10_000 ether);

        vm.prank(alice);
        collateral.approve(address(pool), type(uint256).max);

        vm.prank(alice);
        borrowToken.approve(address(pool), type(uint256).max);

        vm.prank(bob);
        borrowToken.approve(address(pool), type(uint256).max);
    }

    function testDeposit() public {
        vm.prank(alice);
        pool.deposit(1000 ether);

        assertEq(pool.collateralDeposited(alice), 1000 ether);
    }

    function testBorrowWithinLTV() public {
        vm.prank(alice);
        pool.deposit(1000 ether);

        vm.prank(alice);
        pool.borrow(500 ether);

        assertEq(pool.borrowedAmount(alice), 500 ether);
    }

    function testRevertBorrowExceedsLTV() public {
        vm.prank(alice);
        pool.deposit(1000 ether);

        vm.prank(alice);
        vm.expectRevert("exceeds LTV");
        pool.borrow(800 ether);
    }

    function testRepay() public {
        vm.prank(alice);
        pool.deposit(1000 ether);

        vm.prank(alice);
        pool.borrow(500 ether);

        vm.prank(alice);
        pool.repay(200 ether);

        assertLt(pool.borrowedAmount(alice), 500 ether);
    }

    function testWithdraw() public {
        vm.prank(alice);
        pool.deposit(1000 ether);

        vm.prank(alice);
        pool.withdraw(500 ether);

        assertEq(pool.collateralDeposited(alice), 500 ether);
    }

    function testRevertWithdrawHealthFactor() public {
        vm.prank(alice);
        pool.deposit(1000 ether);

        vm.prank(alice);
        pool.borrow(700 ether);

        vm.prank(alice);
        vm.expectRevert();
        pool.withdraw(500 ether);
    }

    function testLiquidation() public {
        vm.prank(alice);
        pool.deposit(1000 ether);

        vm.prank(alice);
        pool.borrow(700 ether);

        pool.setCollateralPrice(5e17); // price drop

        borrowToken.mint(bob, 1000 ether);

        vm.prank(bob);
        pool.liquidate(alice);

        assertEq(pool.borrowedAmount(alice), 0);
    }

    function testInterestAccrual() public {
        vm.prank(alice);
        pool.deposit(1000 ether);

        vm.prank(alice);
        pool.borrow(500 ether);

        vm.warp(block.timestamp + 365 days);

        vm.prank(alice);
        pool.repay(1 ether);

        assertGt(pool.borrowedAmount(alice), 500 ether);
    }

    function testHealthFactor() public {
        vm.prank(alice);
        pool.deposit(1000 ether);

        vm.prank(alice);
        pool.borrow(500 ether);

        uint256 hf = pool.getHealthFactor(alice);
        assertGt(hf, 1e18);
    }

    function testRevertBorrowWithoutCollateral() public {
        vm.prank(alice);
        vm.expectRevert();
        pool.borrow(100 ether);
    }
}
