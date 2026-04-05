// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../src/MyToken.sol";

contract MyTokenTest is Test {
    MyToken token;

    address alice = address(0x1);
    address bob = address(0x2);
    address charlie = address(0x3);

    function setUp() public {
        token = new MyToken();
        token.mint(alice, 1000 ether);
        token.mint(bob, 500 ether);
    }

    function testMintWorks() public {
        token.mint(charlie, 200 ether);
        assertEq(token.balanceOf(charlie), 200 ether);
    }

    function testMintIncreasesTotalSupply() public {
        uint256 beforeSupply = token.totalSupply();
        token.mint(charlie, 100 ether);
        assertEq(token.totalSupply(), beforeSupply + 100 ether);
    }

    function testTransferWorks() public {
        vm.prank(alice);
        token.transfer(bob, 100 ether);

        assertEq(token.balanceOf(alice), 900 ether);
        assertEq(token.balanceOf(bob), 600 ether);
    }

    function testApproveWorks() public {
        vm.prank(alice);
        token.approve(bob, 150 ether);

        assertEq(token.allowance(alice, bob), 150 ether);
    }

    function testTransferFromWorks() public {
        vm.prank(alice);
        token.approve(address(this), 200 ether);

        token.transferFrom(alice, bob, 200 ether);

        assertEq(token.balanceOf(alice), 800 ether);
        assertEq(token.balanceOf(bob), 700 ether);
    }

    function testAllowanceDecreasesAfterTransferFrom() public {
        vm.prank(alice);
        token.approve(address(this), 300 ether);

        token.transferFrom(alice, bob, 100 ether);

        assertEq(token.allowance(alice, address(this)), 200 ether);
    }

    function testRevertMintToZeroAddress() public {
        vm.expectRevert("zero address");
        token.mint(address(0), 100 ether);
    }

    function testRevertMintZeroAmount() public {
        vm.expectRevert("zero amount");
        token.mint(charlie, 0);
    }

    function testRevertTransferWithoutBalance() public {
        vm.prank(charlie);
        vm.expectRevert();
        token.transfer(alice, 1 ether);
    }

    function testRevertTransferFromWithoutAllowance() public {
        vm.prank(bob);
        vm.expectRevert();
        token.transferFrom(alice, charlie, 1 ether);
    }

    function testFuzzTransfer(uint256 amount) public {
        vm.assume(amount > 0 && amount <= 1000 ether);

        vm.prank(alice);
        token.transfer(bob, amount);

        assertEq(token.balanceOf(alice), 1000 ether - amount);
        assertEq(token.balanceOf(bob), 500 ether + amount);
    }
}
