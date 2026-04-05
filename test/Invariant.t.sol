// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../src/MyToken.sol";

contract InvariantTest is Test {
    MyToken token;

    address alice = address(0x1);
    address bob = address(0x2);

    function setUp() public {
        token = new MyToken();
        token.mint(alice, 1000 ether);
        token.mint(bob, 500 ether);
    }

    // Invariant 1: totalSupply никогда не меняется от transfer
    function invariant_TotalSupplyConstant() public {
        uint256 supply = token.totalSupply();

        vm.prank(alice);
        token.transfer(bob, 100 ether);

        assertEq(token.totalSupply(), supply);
    }

    // Invariant 2: баланс не может быть больше totalSupply
    function invariant_BalanceNeverExceedsSupply() public {
        assertLe(token.balanceOf(alice), token.totalSupply());
        assertLe(token.balanceOf(bob), token.totalSupply());
    }
}