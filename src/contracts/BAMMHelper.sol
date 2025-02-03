// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

// ====================================================================
// |     ______                   _______                             |
// |    / _____________ __  __   / ____(_____  ____ _____  ________   |
// |   / /_  / ___/ __ `| |/_/  / /_  / / __ \/ __ `/ __ \/ ___/ _ \  |
// |  / __/ / /  / /_/ _>  <   / __/ / / / / / /_/ / / / / /__/  __/  |
// | /_/   /_/   \__,_/_/|_|  /_/   /_/_/ /_/\__,_/_/ /_/\___/\___/   |
// |                                                                  |
// ====================================================================
// ============================ BAMMHelper ============================
// ====================================================================
// Has helper functions for the BAMM, especially for unbalanced liquidity calculations

import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";

import { IFraxswapPair } from "dev-fraxswap/src/contracts/core/interfaces/IFraxswapPair.sol";

contract BAMMHelper {
    /// @notice Semantic version of this contract
    /// @return _major The major version
    /// @return _minor The minor version
    /// @return _patch The patch version
    function version() external pure returns (uint256 _major, uint256 _minor, uint256 _patch) {
        return (0, 5, 2);
    }

    /// @notice Mints LP from token0 and token1. Swaps to balance the pool first if token0 and token1 are not at the current pool ratio.
    /// @param token0Amount Amount of token0 being sent
    /// @param token1Amount Amount of token1 being sent
    /// @param minLiquidity Minimum amount of LP output expected
    /// @param pool The LP contract
    function addLiquidityUnbalanced(
        uint256 token0Amount,
        uint256 token1Amount,
        uint256 minLiquidity,
        IFraxswapPair pool
    ) external returns (uint256 liquidity) {
        // Make sure TWAMM orders are executed first
        pool.executeVirtualOrders(block.timestamp);

        // Get the new reserves
        (uint112 reserve0, uint112 reserve1, ) = pool.getReserves();

        // Get the fee for the pool
        uint256 fee = pool.fee();

        // Get the amount to swap. Can be negative.
        IERC20 token0 = IERC20(pool.token0());
        IERC20 token1 = IERC20(pool.token1());
        int256 swapAmount = getSwapAmount(
            int256(uint256(reserve0)),
            int256(uint256(reserve1)),
            int256(token0Amount),
            int256(token1Amount),
            int256(fee)
        );

        // Positive = token0 --> token1, Negative = token1 --> token0;
        // Swap to make the pool balanced
        if (swapAmount > 0) {
            // Swap token0 for token1
            // xy = k
            uint256 amountOut = getAmountOut(reserve0, reserve1, fee, uint256(swapAmount));

            if (amountOut > 0) {
                // Take token0 from the sender and give it to the pool
                SafeERC20.safeTransferFrom(token0, msg.sender, address(pool), uint256(swapAmount));

                // Swap token0 (excess sitting in the pool) for token1
                pool.swap(0, amountOut, address(this), "");

                // Give the received token1 to the LP for later minting
                SafeERC20.safeTransfer(token1, address(pool), amountOut);

                // Subtract the amount of token0 sent in for the swap
                token0Amount -= uint256(swapAmount);
            }
        } else {
            // Swap token1 for token0
            // xy = k
            uint256 amountOut = getAmountOut(reserve1, reserve0, fee, uint256(-swapAmount));

            if (amountOut > 0) {
                // Take token1 from the sender and give it to the pool
                SafeERC20.safeTransferFrom(token1, msg.sender, address(pool), uint256(-swapAmount));

                // Swap token1 (excess sitting in the pool) for token0
                pool.swap(amountOut, 0, address(this), "");

                // Give the received token0 to the LP for later minting
                SafeERC20.safeTransfer(token0, address(pool), amountOut);

                // Subtract the amount of token1 sent in for the swap
                token1Amount -= uint256(-swapAmount);
            }
        }

        // Take the token0 and token1 from the sender and give it to the LP
        SafeERC20.safeTransferFrom(token0, msg.sender, address(pool), token0Amount);
        SafeERC20.safeTransferFrom(token1, msg.sender, address(pool), token1Amount);

        // Mint() sees the new tokens and will mint LP to msg.sender
        // It also executes long term orders, updates the reserves and price accumulators
        liquidity = pool.mint(msg.sender);

        // Revert if the generated liquidity was not enough
        if (liquidity < minLiquidity) revert("minLiquidity");
    }

    /// @notice Estimates the amount of LP minted from sending a possibly imbalanced amount of token0 and token1
    /// @param token0Amount Amount of token0 being sent
    /// @param token1Amount Amount of token1 being sent
    /// @param pool The LP contract
    /// @return liquidity Amount of LP tokens expected
    function estimateLiquidityUnbalanced(
        uint256 token0Amount,
        uint256 token1Amount,
        IFraxswapPair pool
    ) public view returns (uint256 liquidity, int256 swapAmount) {
        // Get the pool reserves
        uint112 reserve0;
        uint112 reserve1;
        (reserve0, reserve1, , , ) = pool.getReserveAfterTwamm(block.timestamp);

        // get the fee for the pool
        uint256 fee = pool.fee();

        // Get the amount to swap. Can be negative.
        swapAmount = getSwapAmount(
            int256(uint256(reserve0)),
            int256(uint256(reserve1)),
            int256(token0Amount),
            int256(token1Amount),
            int256(fee)
        );

        // Positive = token0 --> token1, Negative = token1 --> token0;
        if (swapAmount > 0) {
            // xy = k
            uint256 amountOut = getAmountOut(reserve0, reserve1, fee, uint256(swapAmount));

            // Update local vars
            token0Amount -= uint256(swapAmount);
            token1Amount += amountOut;
            reserve0 += uint112(uint256(swapAmount));
            reserve1 -= uint112(amountOut);
        } else {
            // xy = k
            uint256 amountOut = getAmountOut(reserve1, reserve0, fee, uint256(-swapAmount));

            // Update local vars
            token1Amount -= uint256(-swapAmount);
            token0Amount += amountOut;
            reserve1 += uint112(uint256(-swapAmount));
            reserve0 -= uint112(amountOut);
        }

        // Estimate the amount of LP that would be generated
        uint256 _totalSupply = pool.totalSupply();
        liquidity = Math.min((token0Amount * _totalSupply) / reserve0, (token1Amount * _totalSupply) / reserve1);
    }

    /// @notice Use xy = k to get the amount of output tokens from a swap
    /// @param reserveIn Reserves of the input token
    /// @param reserveOut Reserves of the output token
    /// @param fee The swap fee for the LP
    /// @param amountIn Amount of input token
    /// @return uint Amount other token expected to be outputted
    function getAmountOut(
        uint112 reserveIn,
        uint112 reserveOut,
        uint256 fee,
        uint256 amountIn
    ) internal pure returns (uint256) {
        uint256 amountInWithFee = amountIn * fee;
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = (uint256(reserveIn) * 10_000) + amountInWithFee;
        return numerator / denominator;
    }

    /// @notice Uses xy = k. Calculates which token, and how much of it, need to be swapped to balance the pool.
    /// @param reserveA Reserves of token A (not necessarily token0)
    /// @param reserveB Reserves of token B (not necessarily token1)
    /// @param amountA Amount of token A coming in
    /// @param amountB Amount of token B coming in
    /// @return result The amount that needs to be swapped. Positive = tokenA, Negative = tokenB;
    function getSwapAmount(
        int256 reserveA,
        int256 reserveB,
        int256 amountA,
        int256 amountB,
        int256 fee
    ) public view returns (int256 result) {
        // Check to see if you need to re-call the function with the inputs swapped
        if (amountA * reserveB >= amountB * reserveA) {
            // Inputs are ok as-is
            int256 resultOld;
            int256 resultOutOld;
            int256 resultAfterFee;
            int256 XA = reserveA + amountA;
            int256 YB = reserveB + amountB;
            int256 resultOut;
            int256 diffResult;

            // Magical math
            for (uint256 i = 0; i < 100; i++) {
                result = (result + (amountA - ((resultOutOld + amountB) * XA) / YB)) >> 1;

                // Stop when result converges
                if (result != 0 && (((result - resultOld) * 10_000_000) / result) != 0) {
                    resultAfterFee = (result * fee) / 10_000;
                    resultOut = (resultAfterFee * reserveB) / (reserveA + resultAfterFee);
                    diffResult = resultOut - resultOutOld;

                    // Stop when resultsOut converges
                    if (diffResult > -2 && diffResult < 2) break;

                    // Otherwise keep looping
                    resultOld = result;
                    resultOutOld = resultOut;
                } else {
                    break;
                }
            }
        } else {
            // Swap the inputs and try this function again
            result = -getSwapAmount(reserveB, reserveA, amountB, amountA, fee);
        }
    }

    /// @notice Solve getSwapAmount
    /// @param reserveA Reserves of token A (not necessarily token0)
    /// @param reserveB Reserves of token B (not necessarily token1)
    /// @param amountA Amount of token A coming in
    /// @param amountB Amount of token B coming in
    /// @return result The amount that needs to be swapped. Positive = tokenA is swapped out, Negative = tokenB is swapped out.
    function getSwapAmountSolve(
        int256 reserveA,
        int256 reserveB,
        int256 amountA,
        int256 amountB,
        int256 fee
    ) public pure returns (int256 result) {
        if ((amountA * reserveB) > (amountB * reserveA)) {
            result = _getSwapAmountSolve(reserveA, reserveB, amountA, amountB, fee);
            if (result < 0) revert("getSwapAmount 1");
        } else {
            result = -_getSwapAmountSolve(reserveB, reserveA, amountB, amountA, fee);
            if (result > 0) revert("getSwapAmount 2");
        }
    }

    /// @notice Solve getSwapAmount (internal)
    /// @param reserveA Reserves of token A (not necessarily token0)
    /// @param reserveB Reserves of token B (not necessarily token1)
    /// @param amountA Amount of token A coming in
    /// @param amountB Amount of token B coming in
    /// @return result The amount that needs to be swapped. Positive = tokenA is swapped out, Negative = tokenB is swapped out.
    function _getSwapAmountSolve(
        int256 reserveA,
        int256 reserveB,
        int256 amountA,
        int256 amountB,
        int256 fee
    ) internal pure returns (int256 result) {
        // Magical math
        int256 a = (fee * (reserveB + amountB)) / 10_000;
        int256 b = (((fee + 10_000) * (reserveA * (reserveB + amountB))) / 10_000);
        int256 c;
        uint256 divC;
        {
            (int256 c1, uint256 divC1) = mul(reserveA * reserveA, amountB);
            (int256 c2, uint256 divC2) = mul(reserveA * reserveB, amountA);
            if (divC1 > divC2) {
                c = (c1 - c2) / int256(2 ** (divC1 - divC2));
                divC = divC1;
            } else if (divC1 < divC2) {
                c = c1 / int256(2 ** (divC2 - divC1)) - c2;
                divC = divC2;
            } else {
                c = c1 - c2;
                divC = divC1;
            }
        }
        (int256 b2, uint256 divB2) = mul(b, b);
        (int256 ac4, uint256 divAc4) = mul(4 * a, c);
        divAc4 += divC;
        int256 s;
        uint256 divS;
        if (divB2 > divAc4) {
            s = (b2 - ac4) / int256(2 ** (divB2 - divAc4));
            divS = divB2;
        } else if (divB2 < divAc4) {
            s = (b2 / int256(2 ** (divAc4 - divB2))) - ac4;
            divS = divAc4;
        } else {
            s = b2 - ac4;
            divS = divB2;
        }

        if (divS % 2 == 1) {
            s = s / 2;
            divS++;
        }
        result = (sqrtInt(s) * int256(2 ** (divS / 2)) - b) / (2 * a);
    }

    /// @notice Return the log in base 2
    /// @param val The number to log
    /// @return result The resulting logarithm
    function log2(int256 val) internal pure returns (uint256 result) {
        result = 1;
        if (val < 0) val = -val;
        if (val > 2 ** 128) {
            result += 128;
            val = val / (2 ** 128);
        }
        if (val > 2 ** 64) {
            result += 64;
            val = val / (2 ** 64);
        }
        if (val > 2 ** 32) {
            result += 32;
            val = val / (2 ** 32);
        }
        if (val > 2 ** 16) {
            result += 16;
            val = val / (2 ** 16);
        }
        if (val > 2 ** 8) {
            result += 8;
            val = val / (2 ** 8);
        }
        if (val > 2 ** 4) {
            result += 4;
            val = val / (2 ** 4);
        }
        if (val > 2 ** 2) {
            result += 2;
            val = val / (2 ** 2);
        }
        if (val > 2) {
            result += 1;
        }
    }

    /// @notice Computes square roots using the Babylonian method. Casts an int to a uint
    /// @param y The number to root
    /// @return int The resulting root
    // https://en.wikipedia.org/wiki/Methods_of_computing_square_roots#Babylonian_method
    function sqrtInt(int256 y) internal pure returns (int256) {
        return int256(sqrt(uint256(y)));
    }

    /// @notice Computes square roots using the Babylonian method
    /// @param y The number to root
    /// @return z The resulting root
    // https://en.wikipedia.org/wiki/Methods_of_computing_square_roots#Babylonian_method
    function sqrt(uint256 y) internal pure returns (uint256 z) {
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

    /// @notice Multiply some numbers using log2
    /// @param a Multiplier
    /// @param b Multiplicand
    /// @return result The multiplication result
    /// @return div
    function mul(int256 a, int256 b) internal pure returns (int256 result, uint256 div) {
        uint256 logA = log2(a);
        uint256 logB = log2(b);
        if ((logA + logB) > 252) {
            div = logA + logB - 252;
            uint256 divA = (logA * div) / (logA + logB);
            uint256 divB = div - divA;
            result = (a / int256(2 ** divA)) * (b / int256(2 ** divB));
        } else {
            result = a * b;
        }
    }
}
