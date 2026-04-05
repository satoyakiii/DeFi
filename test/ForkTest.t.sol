// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";

interface IERC20 {
    function totalSupply() external view returns (uint256);
}

contract ForkTest is Test {
    uint256 forkId;

    function setUp() public {
        forkId = vm.createSelectFork(vm.envString("RPC_URL"));
    }

    function testReadUSDC() public {
        // USDC contract (Ethereum mainnet)
        address usdc = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

        uint256 supply = IERC20(usdc).totalSupply();

        // просто проверка что supply > 0
        assertGt(supply, 0);
    }
}
