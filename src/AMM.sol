// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./LPToken.sol";

contract AMM {
    IERC20 public tokenA;
    IERC20 public tokenB;
    LPToken public lpToken;

    uint256 public reserveA;
    uint256 public reserveB;

    event LiquidityAdded(address indexed provider, uint256 amountA, uint256 amountB, uint256 lpMinted);
    event LiquidityRemoved(address indexed provider, uint256 amountA, uint256 amountB, uint256 lpBurned);
    event Swap(address indexed user, address indexed tokenIn, uint256 amountIn, address indexed tokenOut, uint256 amountOut);

    constructor(address _tokenA, address _tokenB) {
        require(_tokenA != _tokenB, "same tokens");
        tokenA = IERC20(_tokenA);
        tokenB = IERC20(_tokenB);
        lpToken = new LPToken();
    }

    function _min(uint256 x, uint256 y) internal pure returns (uint256) {
        return x < y ? x : y;
    }

    function _sqrt(uint256 y) internal pure returns (uint256 z) {
        if (y > 3) {
            z = y;
            uint256 x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }

    function addLiquidity(uint256 amountA, uint256 amountB) external returns (uint256 lpMinted) {
        require(amountA > 0 && amountB > 0, "zero amount");

        require(tokenA.transferFrom(msg.sender, address(this), amountA), "transferA failed");
        require(tokenB.transferFrom(msg.sender, address(this), amountB), "transferB failed");

        uint256 totalSupply = lpToken.totalSupply();

        if (totalSupply == 0) {
            lpMinted = _sqrt(amountA * amountB);
        } else {
            uint256 lpFromA = (amountA * totalSupply) / reserveA;
            uint256 lpFromB = (amountB * totalSupply) / reserveB;
            lpMinted = _min(lpFromA, lpFromB);
        }

        require(lpMinted > 0, "zero lp minted");

        reserveA += amountA;
        reserveB += amountB;

        lpToken.mint(msg.sender, lpMinted);

        emit LiquidityAdded(msg.sender, amountA, amountB, lpMinted);
    }

    function removeLiquidity(uint256 lpAmount) external returns (uint256 amountA, uint256 amountB) {
        require(lpAmount > 0, "zero lp");

        uint256 totalSupply = lpToken.totalSupply();
        require(totalSupply > 0, "no liquidity");

        amountA = (lpAmount * reserveA) / totalSupply;
        amountB = (lpAmount * reserveB) / totalSupply;

        require(amountA > 0 && amountB > 0, "zero withdrawal");

        lpToken.burn(msg.sender, lpAmount);

        reserveA -= amountA;
        reserveB -= amountB;

        require(tokenA.transfer(msg.sender, amountA), "transferA failed");
        require(tokenB.transfer(msg.sender, amountB), "transferB failed");

        emit LiquidityRemoved(msg.sender, amountA, amountB, lpAmount);
    }

    function getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut) public pure returns (uint256) {
        require(amountIn > 0, "zero input");
        require(reserveIn > 0 && reserveOut > 0, "bad reserves");

        uint256 amountInWithFee = amountIn * 997;
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = reserveIn * 1000 + amountInWithFee;

        return numerator / denominator;
    }

    function swap(address tokenIn, uint256 amountIn, uint256 minAmountOut) external returns (uint256 amountOut) {
        require(amountIn > 0, "zero input");
        require(tokenIn == address(tokenA) || tokenIn == address(tokenB), "invalid token");

        bool isTokenAIn = tokenIn == address(tokenA);

        IERC20 inToken = isTokenAIn ? tokenA : tokenB;
        IERC20 outToken = isTokenAIn ? tokenB : tokenA;

        uint256 reserveIn = isTokenAIn ? reserveA : reserveB;
        uint256 reserveOut = isTokenAIn ? reserveB : reserveA;

        amountOut = getAmountOut(amountIn, reserveIn, reserveOut);
        require(amountOut >= minAmountOut, "slippage too high");

        require(inToken.transferFrom(msg.sender, address(this), amountIn), "transfer in failed");
        require(outToken.transfer(msg.sender, amountOut), "transfer out failed");

        if (isTokenAIn) {
            reserveA += amountIn;
            reserveB -= amountOut;
        } else {
            reserveB += amountIn;
            reserveA -= amountOut;
        }

        emit Swap(msg.sender, tokenIn, amountIn, address(outToken), amountOut);
    }
}