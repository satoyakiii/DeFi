// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract LendingPool {
    IERC20 public collateralToken;
    IERC20 public borrowToken;

    uint256 public collateralPrice = 1e18; // 1 collateral = 1 borrow token
    uint256 public constant LTV = 75; // 75%
    uint256 public constant LIQUIDATION_THRESHOLD = 1e18; // health factor > 1
    uint256 public constant INTEREST_RATE_PER_SECOND = 3170979198; // ~10% annual scaled roughly

    mapping(address => uint256) public collateralDeposited;
    mapping(address => uint256) public borrowedAmount;
    mapping(address => uint256) public lastUpdate;

    event Deposited(address indexed user, uint256 amount);
    event Borrowed(address indexed user, uint256 amount);
    event Repaid(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event Liquidated(address indexed user, address indexed liquidator, uint256 repaid, uint256 collateralSeized);

    constructor(address _collateralToken, address _borrowToken) {
        collateralToken = IERC20(_collateralToken);
        borrowToken = IERC20(_borrowToken);
    }

    function setCollateralPrice(uint256 newPrice) external {
        collateralPrice = newPrice;
    }

    function deposit(uint256 amount) external {
        require(amount > 0, "zero amount");
        _accrueInterest(msg.sender);

        require(collateralToken.transferFrom(msg.sender, address(this), amount), "transfer failed");
        collateralDeposited[msg.sender] += amount;

        emit Deposited(msg.sender, amount);
    }

    function borrow(uint256 amount) external {
        require(amount > 0, "zero amount");
        _accrueInterest(msg.sender);

        uint256 maxBorrow = getMaxBorrow(msg.sender);
        require(borrowedAmount[msg.sender] + amount <= maxBorrow, "exceeds LTV");

        borrowedAmount[msg.sender] += amount;
        require(borrowToken.transfer(msg.sender, amount), "borrow transfer failed");

        emit Borrowed(msg.sender, amount);
    }

    function repay(uint256 amount) external {
        require(amount > 0, "zero amount");
        _accrueInterest(msg.sender);

        require(borrowedAmount[msg.sender] > 0, "no debt");

        uint256 repayAmount = amount > borrowedAmount[msg.sender] ? borrowedAmount[msg.sender] : amount;

        require(borrowToken.transferFrom(msg.sender, address(this), repayAmount), "repay transfer failed");
        borrowedAmount[msg.sender] -= repayAmount;

        emit Repaid(msg.sender, repayAmount);
    }

    function withdraw(uint256 amount) external {
        require(amount > 0, "zero amount");
        _accrueInterest(msg.sender);
        require(collateralDeposited[msg.sender] >= amount, "not enough collateral");

        collateralDeposited[msg.sender] -= amount;
        require(getHealthFactor(msg.sender) > LIQUIDATION_THRESHOLD || borrowedAmount[msg.sender] == 0, "health factor too low");

        require(collateralToken.transfer(msg.sender, amount), "withdraw transfer failed");

        emit Withdrawn(msg.sender, amount);
    }

    function liquidate(address user) external {
        _accrueInterest(user);
        require(getHealthFactor(user) <= LIQUIDATION_THRESHOLD, "position healthy");

        uint256 debt = borrowedAmount[user];
        require(debt > 0, "no debt");

        require(borrowToken.transferFrom(msg.sender, address(this), debt), "liquidator transfer failed");

        uint256 collateralToSeize = collateralDeposited[user];
        collateralDeposited[user] = 0;
        borrowedAmount[user] = 0;

        require(collateralToken.transfer(msg.sender, collateralToSeize), "collateral transfer failed");

        emit Liquidated(user, msg.sender, debt, collateralToSeize);
    }

    function getMaxBorrow(address user) public view returns (uint256) {
        uint256 collateralValue = (collateralDeposited[user] * collateralPrice) / 1e18;
        return (collateralValue * LTV) / 100;
    }

    function getHealthFactor(address user) public view returns (uint256) {
        if (borrowedAmount[user] == 0) return type(uint256).max;

        uint256 collateralValue = (collateralDeposited[user] * collateralPrice) / 1e18;
        return (collateralValue * 1e18) / borrowedAmount[user];
    }

    function _accrueInterest(address user) internal {
        uint256 last = lastUpdate[user];
        if (last == 0) {
            lastUpdate[user] = block.timestamp;
            return;
        }

        uint256 elapsed = block.timestamp - last;
        if (elapsed > 0 && borrowedAmount[user] > 0) {
            uint256 interest = (borrowedAmount[user] * INTEREST_RATE_PER_SECOND * elapsed) / 1e18;
            borrowedAmount[user] += interest;
        }

        lastUpdate[user] = block.timestamp;
    }
}