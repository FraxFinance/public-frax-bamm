// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

// ====================================================================
// |     ______                   _______                             |
// |    / _____________ __  __   / ____(_____  ____ _____  ________   |
// |   / /_  / ___/ __ `| |/_/  / /_  / / __ \/ __ `/ __ \/ ___/ _ \  |
// |  / __/ / /  / /_/ _>  <   / __/ / / / / / /_/ / / / / /__/  __/  |
// | /_/   /_/   \__,_/_/|_|  /_/   /_/_/ /_/\__,_/_/ /_/\___/\___/   |
// |                                                                  |
// ====================================================================
// =========================== FraxswapOracle =========================
// ====================================================================
// Gets token0 and token1 prices from a Fraxswap pair

import { FixedPoint } from "./libraries/FixedPoint.sol";
import { UQ112x112 } from "./libraries/UQ112x112.sol";
import { IFraxswapPair } from "dev-fraxswap/src/contracts/core/interfaces/IFraxswapPair.sol";
import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import { IFraxswapOracle } from "./interfaces/IFraxswapOracle.sol";

contract FraxswapOracle is IFraxswapOracle {
    using UQ112x112 for uint224;
    using FixedPoint for *;
    using SafeCast for *;

    /// @notice Gets the prices for token0 and token1 from a Fraxswap pool
    /// @param pool The LP contract
    /// @param period The minimum size of the period between observations, in seconds
    /// @param rounds 2 ^ rounds # of blocks to search
    /// @param maxDiffPerc Max price change from last value
    /// @return result0 The price for token0
    /// @return result1 The price for token1
    function getPrice(
        IFraxswapPair pool,
        uint256 period,
        uint256 rounds,
        uint256 maxDiffPerc
    ) public view returns (uint256 result0, uint256 result1) {
        uint256 lastObservationIndex = pool.getTWAPHistoryLength() - 1;
        IFraxswapPair.TWAPObservation memory lastObservation = pool.TWAPObservationHistory(lastObservationIndex);

        // Update last observation up to the current block
        if (lastObservation.timestamp < block.timestamp) {
            // Update the reserves
            (uint112 _reserve0, uint112 _reserve1, ) = pool.getReserves();
            uint32 blockTimestamp = uint32(block.timestamp % 2 ** 32);
            // Get the latest observed prices
            unchecked {
                uint32 timeElapsed = blockTimestamp - uint32(lastObservation.timestamp);
                lastObservation.price0CumulativeLast +=
                    uint256(UQ112x112.encode(_reserve1).uqdiv(_reserve0)) *
                    timeElapsed;
                lastObservation.price1CumulativeLast +=
                    uint256(UQ112x112.encode(_reserve0).uqdiv(_reserve1)) *
                    timeElapsed;
                lastObservation.timestamp = blockTimestamp;
            }
        }

        bool found;
        // Search for an observation via binary search within the last 2^round number of observations
        IFraxswapPair.TWAPObservation memory foundObservation;
        uint256 step = 2 ** rounds;
        uint256 min = (lastObservationIndex + 2 > step) ? (lastObservationIndex + 2 - step) : 0;
        while (step > 1) {
            step = step >> 1; // divide by 2
            uint256 pos = min + step - 1;
            if (pos <= lastObservationIndex) {
                IFraxswapPair.TWAPObservation memory observation = pool.TWAPObservationHistory(pos);
                unchecked {
                    if (lastObservation.timestamp - observation.timestamp > period) {
                        found = true;
                        foundObservation = observation;
                        min = pos + 1;
                    }
                }
            }
        }

        // Reverts when a matching period can not be found
        require(found, "Period too long");

        // Get the price results 1E34 based
        uint256 encoded0;
        uint256 encoded1;
        unchecked {
            encoded0 =
                (lastObservation.price0CumulativeLast - foundObservation.price0CumulativeLast) /
                uint32(lastObservation.timestamp - foundObservation.timestamp);
            encoded1 =
                (lastObservation.price1CumulativeLast - foundObservation.price1CumulativeLast) /
                uint32(lastObservation.timestamp - foundObservation.timestamp);
        }

        // Handwave unit conversion given: https://github.com/Uniswap/v2-periphery/blob/0335e8f7e1bd1e8d8329fd300aea2ef2f36dd19f/contracts/examples/ExampleSlidingWindowOracle.sol#L99
        result0 = mulDecode(encoded0.toUint224());
        result1 = mulDecode(encoded1.toUint224());

        // Revert if the price changed too much
        uint256 checkResult0 = 1e68 / result1;
        uint256 diff = (checkResult0 > result0 ? checkResult0 - result0 : result0 - checkResult0);
        uint256 diffPerc = (diff * 10_000) / result0;
        if (diffPerc > maxDiffPerc) revert("Max diff");
    }

    /// @notice Gets the prices for token0 from a Fraxswap pool
    /// @param pool The LP contract
    /// @param period The minimum size of the period between observations, in seconds
    /// @param rounds 2 ^ rounds # of blocks to search
    /// @param maxDiffPerc Max price change from last value
    /// @return result0 The price for token0
    function getPrice0(
        IFraxswapPair pool,
        uint256 period,
        uint256 rounds,
        uint256 maxDiffPerc
    ) external view returns (uint256 result0) {
        (result0, ) = getPrice(pool, period, rounds, maxDiffPerc);
    }

    /// @notice Gets the price for token1 from a Fraxswap pool
    /// @param pool The LP contract
    /// @param period The minimum size of the period between observations, in seconds
    /// @param rounds 2 ^ rounds # of blocks to search
    /// @param maxDiffPerc Max price change from last value
    /// @return result1 The price for token1
    function getPrice1(
        IFraxswapPair pool,
        uint256 period,
        uint256 rounds,
        uint256 maxDiffPerc
    ) external view returns (uint256 result1) {
        (, result1) = getPrice(pool, period, rounds, maxDiffPerc);
    }

    // multiplies the uq112x112 with 1E34 without overflowing and then converting it to uint.
    function mulDecode(uint224 value) public pure returns (uint256 result) {
        if (value < type(uint224).max / 1e34) {
            result = FixedPoint.uq112x112(value).mul(1e34).decode144();
        } else if (value < type(uint224).max / 1e17) {
            result = uint256(FixedPoint.uq112x112(value).mul(1e17).decode144()) * 1e17;
        } else {
            result = uint256(FixedPoint.uq112x112(value).decode()) * 1e34;
        }
    }
}
