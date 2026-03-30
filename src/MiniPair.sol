// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./MockERC20.sol";

contract MiniPair {

    // ========== STATE VARIABLES ==========
    MockERC20 public tokenA;
    MockERC20 public tokenB;

    uint256 public reserveA;
    uint256 public reserveB;

    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;

    uint256 public constant MINIMUM_LIQUIDITY = 1000;

    address public factory;
    bool private locked;
    bool public initialized;

    // ========== EVENTS ==========
    event Mint(address indexed sender, uint256 amountA, uint256 amountB, uint256 liquidity);
    event Burn(address indexed sender, uint256 amountA, uint256 amountB, uint256 liquidity);
    event Swap(address indexed sender, uint256 amountIn, address tokenIn, uint256 amountOut, address tokenOut);

    modifier noReentrant() {
        require(!locked, "MiniPair: LOCKED");
        locked = true;
        _;
        locked = false;
    }

    constructor() {
        factory = msg.sender;  // Only Factory can create pairs
    }

    function initialize(address _tokenA, address _tokenB) external {
        require(msg.sender == factory, "MiniPair: FORBIDDEN");
        require(!initialized, "MiniPair: ALREADY_INITIALIZED");

        tokenA = MockERC20(_tokenA);
        tokenB = MockERC20(_tokenB);
        initialized = true;
    }

    // ========== CORE FUNCTIONS (same as before) ==========

    function addLiquidity(uint256 amountA, uint256 amountB)
        external noReentrant returns (uint256 liquidity)
    {
        require(amountA > 0 && amountB > 0, "MiniPair: INSUFFICIENT_AMOUNTS");

        require(tokenA.transferFrom(msg.sender, address(this), amountA), "MiniPair: TRANSFER_A_FAILED");
        require(tokenB.transferFrom(msg.sender, address(this), amountB), "MiniPair: TRANSFER_B_FAILED");

        if (totalSupply == 0) {
            liquidity = _sqrt(amountA * amountB) - MINIMUM_LIQUIDITY;
            require(liquidity > 0, "MiniPair: INSUFFICIENT_LIQUIDITY_MINTED");
            balanceOf[address(0)] = MINIMUM_LIQUIDITY;
            totalSupply = MINIMUM_LIQUIDITY;
        } else {
            uint256 liquidityA = (amountA * totalSupply) / reserveA;
            uint256 liquidityB = (amountB * totalSupply) / reserveB;
            liquidity = liquidityA < liquidityB ? liquidityA : liquidityB;
            require(liquidity > 0, "MiniPair: INSUFFICIENT_LIQUIDITY_MINTED");
        }

        balanceOf[msg.sender] += liquidity;
        totalSupply += liquidity;
        reserveA += amountA;
        reserveB += amountB;

        emit Mint(msg.sender, amountA, amountB, liquidity);
    }

    function removeLiquidity(uint256 liquidity)
        external noReentrant returns (uint256 amountA, uint256 amountB)
    {
        require(liquidity > 0, "MiniPair: INSUFFICIENT_LIQUIDITY");
        require(balanceOf[msg.sender] >= liquidity, "MiniPair: INSUFFICIENT_BALANCE");

        amountA = (liquidity * reserveA) / totalSupply;
        amountB = (liquidity * reserveB) / totalSupply;
        require(amountA > 0 && amountB > 0, "MiniPair: INSUFFICIENT_LIQUIDITY_BURNED");

        balanceOf[msg.sender] -= liquidity;
        totalSupply -= liquidity;
        reserveA -= amountA;
        reserveB -= amountB;

        require(tokenA.transfer(msg.sender, amountA), "MiniPair: TRANSFER_A_FAILED");
        require(tokenB.transfer(msg.sender, amountB), "MiniPair: TRANSFER_B_FAILED");

        emit Burn(msg.sender, amountA, amountB, liquidity);
    }

    function swap(address _tokenIn, uint256 amountIn)
        external noReentrant returns (uint256 amountOut)
    {
        require(amountIn > 0, "MiniPair: INSUFFICIENT_INPUT");
        require(_tokenIn == address(tokenA) || _tokenIn == address(tokenB), "MiniPair: INVALID_TOKEN");

        bool isTokenA = _tokenIn == address(tokenA);

        (MockERC20 tokenIn, MockERC20 tokenOut, uint256 reserveIn, uint256 reserveOut) = isTokenA
            ? (tokenA, tokenB, reserveA, reserveB)
            : (tokenB, tokenA, reserveB, reserveA);

        require(tokenIn.transferFrom(msg.sender, address(this), amountIn), "MiniPair: TRANSFER_IN_FAILED");

        uint256 amountInWithFee = amountIn * 997;
        amountOut = (reserveOut * amountInWithFee) / (reserveIn * 1000 + amountInWithFee);

        require(amountOut > 0, "MiniPair: INSUFFICIENT_OUTPUT");
        require(amountOut < reserveOut, "MiniPair: INSUFFICIENT_LIQUIDITY");

        require(tokenOut.transfer(msg.sender, amountOut), "MiniPair: TRANSFER_OUT_FAILED");

        if (isTokenA) {
            reserveA += amountIn;
            reserveB -= amountOut;
        } else {
            reserveB += amountIn;
            reserveA -= amountOut;
        }

        emit Swap(msg.sender, amountIn, _tokenIn, amountOut, address(tokenOut));
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        require(to != address(0), "MiniPair: TRANSFER_TO_ZERO");
        require(balanceOf[msg.sender] >= amount, "MiniPair: INSUFFICIENT_LP");

        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        return true;
    }

    // ========== VIEW FUNCTIONS ==========

    function getPriceA() external view returns (uint256) {
        require(reserveA > 0, "MiniPair: NO_RESERVES");
        return (reserveB * 1e18) / reserveA;
    }

    function getPriceB() external view returns (uint256) {
        require(reserveB > 0, "MiniPair: NO_RESERVES");
        return (reserveA * 1e18) / reserveB;
    }

    function getAmountOut(uint256 amountIn, uint256 _reserveIn, uint256 _reserveOut)
        public pure returns (uint256)
    {
        require(amountIn > 0, "MiniPair: INSUFFICIENT_INPUT");
        require(_reserveIn > 0 && _reserveOut > 0, "MiniPair: INSUFFICIENT_LIQUIDITY");
        uint256 amountInWithFee = amountIn * 997;
        return (amountInWithFee * _reserveOut) / (_reserveIn * 1000 + amountInWithFee);
    }

    function getReserves() external view returns (uint256, uint256) {
        return (reserveA, reserveB);
    }

    // ========== INTERNAL ==========

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
}