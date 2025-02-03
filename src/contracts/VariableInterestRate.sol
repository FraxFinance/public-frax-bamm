// SPDX-License-Identifier: ISC
pragma solidity 0.8.23;

// ====================================================================
// |     ______                   _______                             |
// |    / _____________ __  __   / ____(_____  ____ _____  ________   |
// |   / /_  / ___/ __ `| |/_/  / /_  / / __ \/ __ `/ __ \/ ___/ _ \  |
// |  / __/ / /  / /_/ _>  <   / __/ / / / / / /_/ / / / / /__/  __/  |
// | /_/   /_/   \__,_/_/|_|  /_/   /_/_/ /_/\__,_/_/ /_/\___/\___/   |
// |                                                                  |
// ====================================================================
// ====================== VariableInterestRate ========================
// ====================================================================

import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { IVariableInterestRate } from "./interfaces/IVariableInterestRate.sol";

/// @title A formula for calculating interest rates as a function of utilization and time
/// @author Frax Finance (https://github.com/FraxFinance)
/// @notice A Contract for calculating interest rates as a function of utilization and time
contract VariableInterestRate is IVariableInterestRate {
    using Strings for uint256;

    /// @notice The name suffix for the interest rate calculator
    string public suffix;

    // Utilization Settings
    /// @notice The minimum utilization wherein no adjustment to full utilization and vertex rates occurs
    uint256 public immutable MIN_TARGET_UTIL;
    /// @notice The maximum utilization wherein no adjustment to full utilization and vertex rates occurs
    uint256 public immutable MAX_TARGET_UTIL;
    /// @notice The utilization at which the slope increases
    uint256 public immutable VERTEX_UTILIZATION;
    /// @notice The second utilization at which the slope increases
    uint256 public immutable VERTEX_2_UTILIZATION;
    /// @notice precision of utilization calculations
    uint256 public constant UTIL_PREC = 1e5; // 5 decimals

    // Interest Rate Settings (all rates are per second), 365.24 days per year
    /// @notice The minimum interest rate (per second) when utilization is 100%
    uint256 public immutable MIN_FULL_UTIL_RATE; // 18 decimals
    /// @notice The maximum interest rate (per second) when utilization is 100%
    uint256 public immutable MAX_FULL_UTIL_RATE; // 18 decimals
    /// @notice The interest rate (per second) when utilization is 0%
    uint256 public immutable ZERO_UTIL_RATE; // 18 decimals
    /// @notice The interest rate half life in seconds, determines rate of adjustments to rate curve
    uint256 public immutable RATE_HALF_LIFE; // 1 decimals
    /// @notice The percent of the delta between max and min at the first kink
    uint256 public immutable VERTEX_RATE_PERCENT; // 18 decimals
    /// @notice The percent of the delta between max and min at the second kink
    uint256 public immutable VERTEX_2_RATE_PERCENT; // 18 decimals
    /// @notice The precision of interest rate calculations
    uint256 public constant RATE_PREC = 1e18; // 18 decimals

    error MaxUtilizationTooLow();
    error MaxFullUtilizationTooLow();
    error DivideByZero();
    error VertexUtilizationTooHigh();
    error UtilizationRateTooHigh();
    error Vertex2UtilizationTooLow();

    /// @param _params Abi Encoding of the following schema:
    /// param _suffix The suffix of the contract name
    /// param _vertexUtilization The utilization at which the slope increases
    /// param _vertex2Utilization The utilization at which the slope increases
    /// param _vertexRatePercentOfDelta The percent of the delta between max and min, defines vertex rate
    /// param _vertex2RatePercentOfDelta The percent of delta between the
    /// param _minUtil The minimum utilization wherein no adjustment to full utilization and vertex rates occurs
    /// param _maxUtil The maximum utilization wherein no adjustment to full utilization and vertex rates occurs
    /// param _zeroUtilizationRate The interest rate (per second) when utilization is 0%
    /// param _minFullUtilizationRate The minimum interest rate at 100% utilization
    /// param _maxFullUtilizationRate The maximum interest rate at 100% utilization
    /// param _rateHalfLife The half life parameter for interest rate adjustments
    constructor(bytes memory _params) {
        (
            suffix,
            VERTEX_UTILIZATION,
            VERTEX_2_UTILIZATION,
            VERTEX_RATE_PERCENT,
            VERTEX_2_RATE_PERCENT,
            MIN_TARGET_UTIL,
            MAX_TARGET_UTIL,
            ZERO_UTIL_RATE,
            MIN_FULL_UTIL_RATE,
            MAX_FULL_UTIL_RATE,
            RATE_HALF_LIFE
        ) = abi.decode(
            _params,
            (string, uint256, uint256, uint256, uint256, uint256, uint256, uint256, uint256, uint256, uint256)
        );
        if (MAX_TARGET_UTIL <= MIN_TARGET_UTIL) {
            revert MaxUtilizationTooLow();
        }
        if (MAX_FULL_UTIL_RATE <= MIN_FULL_UTIL_RATE) {
            revert MaxFullUtilizationTooLow();
        }

        if (VERTEX_UTILIZATION > UTIL_PREC) {
            revert VertexUtilizationTooHigh();
        }

        if (VERTEX_2_UTILIZATION > UTIL_PREC) {
            revert VertexUtilizationTooHigh();
        }

        if (VERTEX_2_UTILIZATION <= VERTEX_UTILIZATION) {
            revert Vertex2UtilizationTooLow();
        }

        if (
            MAX_TARGET_UTIL == 0 ||
            RATE_HALF_LIFE == 0 ||
            VERTEX_UTILIZATION == 0 ||
            VERTEX_UTILIZATION == UTIL_PREC ||
            VERTEX_2_UTILIZATION == 0 ||
            VERTEX_2_UTILIZATION == UTIL_PREC ||
            MAX_TARGET_UTIL == UTIL_PREC
        ) {
            revert DivideByZero();
        }

        if (MAX_TARGET_UTIL > UTIL_PREC || MAX_FULL_UTIL_RATE > RATE_PREC) {
            revert UtilizationRateTooHigh();
        }
    }

    /// @notice The ```name``` function returns the name of the rate contract
    /// @return memory name of contract
    function name() external view returns (string memory) {
        return string.concat("Variable Rate V3 ", suffix);
    }

    /// @notice The ```version``` function returns the semantic version of the rate contract
    /// @dev Follows semantic versioning
    /// @return _major Major version
    /// @return _minor Minor version
    /// @return _patch Patch version
    function version() external pure returns (uint256 _major, uint256 _minor, uint256 _patch) {
        _major = 3;
        _minor = 0;
        _patch = 1;
    }

    /// @notice The ```getFullUtilizationInterest``` function calculate the new maximum interest rate, i.e. rate when utilization is 100%
    /// @dev Given in interest per second
    /// @param _deltaTime The elapsed time since last update given in seconds
    /// @param _utilization The utilization %, given with 5 decimals of precision
    /// @param _fullUtilizationInterest The interest value when utilization is 100%, given with 18 decimals of precision
    /// @return _newFullUtilizationInterest The new maximum interest rate
    function getFullUtilizationInterest(
        uint256 _deltaTime,
        uint256 _utilization,
        uint64 _fullUtilizationInterest
    ) internal view returns (uint64 _newFullUtilizationInterest) {
        if (_utilization < MIN_TARGET_UTIL) {
            // 18 decimals
            uint256 _deltaUtilization = ((MIN_TARGET_UTIL - _utilization) * 1e18) / MIN_TARGET_UTIL;
            // 36 decimals
            uint256 _decayGrowth = (RATE_HALF_LIFE * 1e36) + (_deltaUtilization * _deltaUtilization * _deltaTime);
            // 18 decimals
            _newFullUtilizationInterest = uint64((_fullUtilizationInterest * (RATE_HALF_LIFE * 1e36)) / _decayGrowth);
        } else if (_utilization > MAX_TARGET_UTIL) {
            // 18 decimals
            uint256 _deltaUtilization = ((_utilization - MAX_TARGET_UTIL) * 1e18) / (UTIL_PREC - MAX_TARGET_UTIL);
            // 36 decimals
            uint256 _decayGrowth = (RATE_HALF_LIFE * 1e36) + (_deltaUtilization * _deltaUtilization * _deltaTime);
            // 18 decimals
            _newFullUtilizationInterest = uint64((_fullUtilizationInterest * _decayGrowth) / (RATE_HALF_LIFE * 1e36));
        } else {
            _newFullUtilizationInterest = _fullUtilizationInterest;
        }
        if (_newFullUtilizationInterest > MAX_FULL_UTIL_RATE) {
            _newFullUtilizationInterest = uint64(MAX_FULL_UTIL_RATE);
        } else if (_newFullUtilizationInterest < MIN_FULL_UTIL_RATE) {
            _newFullUtilizationInterest = uint64(MIN_FULL_UTIL_RATE);
        }
    }

    /// @notice The ```getNewRate``` function calculates interest rates using two linear functions f(utilization)
    /// @param _deltaTime The elapsed time since last update, given in seconds
    /// @param _utilization The utilization %, given with 5 decimals of precision
    /// @param _oldFullUtilizationInterest The interest value when utilization is 100%, given with 18 decimals of precision
    /// @return _newRatePerSec The new interest rate, 18 decimals of precision
    /// @return _newFullUtilizationInterest The new max interest rate, 18 decimals of precision
    function getNewRate(
        uint256 _deltaTime,
        uint256 _utilization,
        uint64 _oldFullUtilizationInterest
    ) external view returns (uint64 _newRatePerSec, uint64 _newFullUtilizationInterest) {
        _newFullUtilizationInterest = getFullUtilizationInterest(_deltaTime, _utilization, _oldFullUtilizationInterest);

        // _vertexInterest is calculated as the percentage of the delta between min and max interest
        uint256 _vertexInterest = (((_newFullUtilizationInterest - ZERO_UTIL_RATE) * VERTEX_RATE_PERCENT) / RATE_PREC) +
            ZERO_UTIL_RATE;
        uint256 _vertex2Interest = (((_newFullUtilizationInterest - ZERO_UTIL_RATE) * VERTEX_2_RATE_PERCENT) /
            RATE_PREC) + ZERO_UTIL_RATE;
        if (_utilization < VERTEX_UTILIZATION) {
            // For readability, the following formula is equivalent to:
            // uint256 _slope = ((_vertexInterest - ZERO_UTIL_RATE) * UTIL_PREC) / VERTEX_UTILIZATION;
            // _newRatePerSec = uint64(ZERO_UTIL_RATE + ((_utilization * _slope) / UTIL_PREC));
            _newRatePerSec = uint64(
                ZERO_UTIL_RATE + (_utilization * (_vertexInterest - ZERO_UTIL_RATE)) / VERTEX_UTILIZATION
            );
        } else if (_utilization < VERTEX_2_UTILIZATION) {
            // For readability, the following formula is equivalent to:
            // uint256 _slope = (((_vertex2Interest - _vertexInterest) * UTIL_PREC) / (VERTEX_2_UTILIZATION - VERTEX_UTILIZATION));
            // _newRatePerSec = uint64(_vertexInterest + (((_utilization - VERTEX_UTILIZATION) * _slope) / UTIL_PREC));
            _newRatePerSec = uint64(
                _vertexInterest +
                    ((_utilization - VERTEX_UTILIZATION) * ((_vertex2Interest - _vertexInterest))) /
                    ((VERTEX_2_UTILIZATION - VERTEX_UTILIZATION))
            );
        } else {
            // For readability, the following formula is equivalent to:
            // uint256 _slope = (((_newFullUtilizationInterest - _vertex2Interest) * UTIL_PREC) / (UTIL_PREC - VERTEX_2_UTILIZATION));
            // _newRatePerSec = uint64(_vertex2Interest + (((_utilization - VERTEX_2_UTILIZATION) * _slope) / UTIL_PREC))
            _newRatePerSec = uint64(
                _vertex2Interest +
                    ((_utilization - VERTEX_2_UTILIZATION) * (_newFullUtilizationInterest - _vertex2Interest)) /
                    ((UTIL_PREC - VERTEX_2_UTILIZATION))
            );
        }
    }
}
