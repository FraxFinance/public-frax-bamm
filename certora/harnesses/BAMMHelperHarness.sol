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

import { BAMMHelper } from "src/contracts/BAMMHelper.sol";

contract BAMMHelperHarness is BAMMHelper {
    function getAmountOut_external(
        uint112 reserveIn,
        uint112 reserveOut,
        uint256 fee,
        uint256 amountIn
    ) external pure returns (uint256) {
        return getAmountOut(reserveIn, reserveOut, fee, amountIn);
    }

    function log2_external(int256 val) external pure returns (uint256) {
        return log2(val);
    }

    function sqrtInt_external(int256 y) external pure returns (int256) {
        return sqrtInt(y);
    }

    function sqrt_external(uint256 y) external pure returns (uint256 z) {
        return sqrt(y);
    }

    function mul_external(int256 a, int256 b) external pure returns (int256, uint256) {
        return mul(a, b);
    }
}
