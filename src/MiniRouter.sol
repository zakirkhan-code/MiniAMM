// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./MiniFactory.sol";
import "./MiniPair.sol";
import "./MockERC20.sol";

contract MiniRouter {
    MiniFactory public immutable factory;

    modifier ensure(uint256 deadline) {
        require(deadline >= block.timestamp, "MiniRouter: EXPIRED");
        _;
    }

    constructor(address _factory) {
        factory = MiniFactory(_factory);
    }


    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external ensure(deadline) returns (uint256 amountA, uint256 amountB, uint256 liquidity) {

        address pairAddr = factory.getPair(tokenA, tokenB);
        require(pairAddr != address(0), "MiniRouter: PAIR_NOT_FOUND");

        MiniPair pair = MiniPair(pairAddr);

        (amountA, amountB) = _calculateLiquidityAmounts(
            pair, tokenA, amountADesired, amountBDesired, amountAMin, amountBMin
        );

        MockERC20(tokenA).transferFrom(msg.sender, address(this), amountA);
        MockERC20(tokenB).transferFrom(msg.sender, address(this), amountB);

        MockERC20(tokenA).approve(address(pair), amountA);
        MockERC20(tokenB).approve(address(pair), amountB);

        address pairToken0 = address(pair.tokenA());
        
        if (pairToken0 == tokenA) {
            liquidity = pair.addLiquidity(amountA, amountB);
        } else {
            liquidity = pair.addLiquidity(amountB, amountA);
        }

        // Transfer LP tokens to recipient
        pair.transfer(to, liquidity);
    }

    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external ensure(deadline) returns (uint256 amountA, uint256 amountB) {

        address pairAddr = factory.getPair(tokenA, tokenB);
        require(pairAddr != address(0), "MiniRouter: PAIR_NOT_FOUND");

        MiniPair pair = MiniPair(pairAddr);

        (uint256 amount0, uint256 amount1) = pair.removeLiquidity(liquidity);

        address pairToken0 = address(pair.tokenA());
        if (pairToken0 == tokenA) {
            amountA = amount0;
            amountB = amount1;
        } else {
            amountA = amount1;
            amountB = amount0;
        }

        // Slippage check
        require(amountA >= amountAMin, "MiniRouter: INSUFFICIENT_A_AMOUNT");
        require(amountB >= amountBMin, "MiniRouter: INSUFFICIENT_B_AMOUNT");

        MockERC20(tokenA).transfer(to, amountA);
        MockERC20(tokenB).transfer(to, amountB);
    }

    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address tokenIn,
        address tokenOut,
        address to,
        uint256 deadline
    ) external ensure(deadline) returns (uint256 amountOut) {

        address pairAddr = factory.getPair(tokenIn, tokenOut);
        require(pairAddr != address(0), "MiniRouter: PAIR_NOT_FOUND");

        MiniPair pair = MiniPair(pairAddr);

        // Transfer input tokens from user to router
        MockERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn);

        // Approve pair
        MockERC20(tokenIn).approve(address(pair), amountIn);

        // Execute swap
        amountOut = pair.swap(tokenIn, amountIn);

        require(amountOut >= amountOutMin, "MiniRouter: INSUFFICIENT_OUTPUT_AMOUNT");

        MockERC20(tokenOut).transfer(to, amountOut);
    }

    function swapExactTokensForTokensMultiHop(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external ensure(deadline) returns (uint256 amountOut) {
        require(path.length >= 2, "MiniRouter: INVALID_PATH");

        MockERC20(path[0]).transferFrom(msg.sender, address(this), amountIn);

        uint256 currentAmount = amountIn;

        for (uint256 i = 0; i < path.length - 1; i++) {
            address currentIn = path[i];
            address currentOut = path[i + 1];

            address pairAddr = factory.getPair(currentIn, currentOut);
            require(pairAddr != address(0), "MiniRouter: PAIR_NOT_FOUND");

            MiniPair pair = MiniPair(pairAddr);

            // Approve pair for current token
            MockERC20(currentIn).approve(address(pair), currentAmount);

            // Swap
            currentAmount = pair.swap(currentIn, currentAmount);
        }

        amountOut = currentAmount;

        // Final slippage check
        require(amountOut >= amountOutMin, "MiniRouter: INSUFFICIENT_OUTPUT_AMOUNT");

        MockERC20(path[path.length - 1]).transfer(to, amountOut);
    }

    function getAmountOut(
        uint256 amountIn,
        address tokenIn,
        address tokenOut
    ) external view returns (uint256) {
        address pairAddr = factory.getPair(tokenIn, tokenOut);
        require(pairAddr != address(0), "MiniRouter: PAIR_NOT_FOUND");

        MiniPair pair = MiniPair(pairAddr);
        
        address pairToken0 = address(pair.tokenA());
        (uint256 reserveA, uint256 reserveB) = pair.getReserves();

        if (pairToken0 == tokenIn) {
            return pair.getAmountOut(amountIn, reserveA, reserveB);
        } else {
            return pair.getAmountOut(amountIn, reserveB, reserveA);
        }
    }

    function getAmountsOut(
        uint256 amountIn,
        address[] calldata path
    ) external view returns (uint256[] memory amounts) {
        require(path.length >= 2, "MiniRouter: INVALID_PATH");
        
        amounts = new uint256[](path.length);
        amounts[0] = amountIn;

        for (uint256 i = 0; i < path.length - 1; i++) {
            address pairAddr = factory.getPair(path[i], path[i + 1]);
            require(pairAddr != address(0), "MiniRouter: PAIR_NOT_FOUND");

            MiniPair pair = MiniPair(pairAddr);
            address pairToken0 = address(pair.tokenA());
            (uint256 reserveA, uint256 reserveB) = pair.getReserves();

            if (pairToken0 == path[i]) {
                amounts[i + 1] = pair.getAmountOut(amounts[i], reserveA, reserveB);
            } else {
                amounts[i + 1] = pair.getAmountOut(amounts[i], reserveB, reserveA);
            }
        }
    }

    function _calculateLiquidityAmounts(
        MiniPair pair,
        address tokenA,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin
    ) internal view returns (uint256 amountA, uint256 amountB) {
        (uint256 reserveA, uint256 reserveB) = pair.getReserves();

        if (reserveA == 0 && reserveB == 0) {
            // First liquidity - use desired amounts as-is
            return (amountADesired, amountBDesired);
        }

        // Map reserves to match tokenA/tokenB order
        address pairToken0 = address(pair.tokenA());
        uint256 resA;
        uint256 resB;
        if (pairToken0 == tokenA) {
            resA = reserveA;
            resB = reserveB;
        } else {
            resA = reserveB;
            resB = reserveA;
        }

        // Calculate optimal amountB for given amountA
        uint256 amountBOptimal = (amountADesired * resB) / resA;

        if (amountBOptimal <= amountBDesired) {
            require(amountBOptimal >= amountBMin, "MiniRouter: INSUFFICIENT_B_AMOUNT");
            return (amountADesired, amountBOptimal);
        } else {
            // Calculate optimal amountA for given amountB
            uint256 amountAOptimal = (amountBDesired * resA) / resB;
            require(amountAOptimal <= amountADesired, "MiniRouter: EXCESSIVE_A_AMOUNT");
            require(amountAOptimal >= amountAMin, "MiniRouter: INSUFFICIENT_A_AMOUNT");
            return (amountAOptimal, amountBDesired);
        }
    }
}