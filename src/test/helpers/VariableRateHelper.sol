pragma solidity ^0.8.10;

import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import "src/contracts/interfaces/IVariableInterestRate.sol";
import "src/contracts/VariableInterestRate.sol";
import "frax-std/FraxTest.sol";

library RateHelper {
    using Strings for *;
    using SafeCast for *;

    // ============================================================================================
    // Interest Rate Helpers
    // ============================================================================================

    struct RateCalculatorParams {
        uint256 MIN_TARGET_UTIL;
        uint256 MAX_TARGET_UTIL;
        uint256 VERTEX_UTILIZATION;
        uint256 UTIL_PREC; // 5 decimals
        uint256 MIN_FULL_UTIL_RATE; // 18 decimals
        uint256 MAX_FULL_UTIL_RATE; // 18 decimals
        uint256 ZERO_UTIL_RATE; // 18 decimals
        uint256 RATE_HALF_LIFE; // 1 decimals
        uint256 VERTEX_RATE_PERCENT; // 18 decimals
        uint256 RATE_PREC;
    }

    function __getRateCalculatorParams(
        IVariableInterestRate _rateCalculator
    ) public view returns (RateCalculatorParams memory _rateCalculatorParams) {
        _rateCalculatorParams.MIN_TARGET_UTIL = _rateCalculator.MIN_TARGET_UTIL();
        _rateCalculatorParams.MAX_TARGET_UTIL = _rateCalculator.MAX_TARGET_UTIL();
        _rateCalculatorParams.VERTEX_UTILIZATION = _rateCalculator.VERTEX_UTILIZATION();
        _rateCalculatorParams.UTIL_PREC = _rateCalculator.UTIL_PREC();
        _rateCalculatorParams.MIN_FULL_UTIL_RATE = _rateCalculator.MIN_FULL_UTIL_RATE();
        _rateCalculatorParams.MAX_FULL_UTIL_RATE = _rateCalculator.MAX_FULL_UTIL_RATE();
        _rateCalculatorParams.ZERO_UTIL_RATE = _rateCalculator.ZERO_UTIL_RATE();
        _rateCalculatorParams.RATE_HALF_LIFE = _rateCalculator.RATE_HALF_LIFE();
        _rateCalculatorParams.VERTEX_RATE_PERCENT = _rateCalculator.VERTEX_RATE_PERCENT();
        _rateCalculatorParams.RATE_PREC = _rateCalculator.RATE_PREC();
    }

    function __getRateCalculatorParams(
        VariableInterestRate _rateCalculator
    ) public view returns (RateCalculatorParams memory _rateCalculatorParams) {
        return __getRateCalculatorParams(IVariableInterestRate(address(_rateCalculator)));
    }

    // helper
    function __interestCalculator(
        VariableInterestRate _rateCalculator,
        uint256 _elapsedTime,
        uint256 _utilization,
        uint256 _fullUtilizationInterest,
        Vm vm
    ) internal returns (uint64, uint64) {
        string[] memory _inputs = new string[](15);
        _inputs[0] = "node";
        _inputs[1] = "src/test/utils/variableInterestRateCalculator.js";
        _inputs[2] = uint256(_elapsedTime).toString();
        _inputs[3] = uint256(_utilization).toString();
        _inputs[4] = uint256(_fullUtilizationInterest).toString();
        _inputs[5] = uint256(_rateCalculator.VERTEX_UTILIZATION()).toString();
        _inputs[6] = uint256(_rateCalculator.VERTEX_2_UTILIZATION()).toString();
        _inputs[7] = uint256(_rateCalculator.VERTEX_RATE_PERCENT()).toString();
        _inputs[8] = uint256(_rateCalculator.VERTEX_2_RATE_PERCENT()).toString();
        _inputs[9] = uint256(_rateCalculator.MIN_TARGET_UTIL()).toString();
        _inputs[10] = uint256(_rateCalculator.MAX_TARGET_UTIL()).toString();
        _inputs[11] = uint256(_rateCalculator.ZERO_UTIL_RATE()).toString();
        _inputs[12] = uint256(_rateCalculator.MIN_FULL_UTIL_RATE()).toString();
        _inputs[13] = uint256(_rateCalculator.MAX_FULL_UTIL_RATE()).toString();
        _inputs[14] = uint256(_rateCalculator.RATE_HALF_LIFE()).toString();
        bytes memory _ret = vm.ffi(_inputs);
        (uint256 _newRatePerSec, uint256 _newFullUtilizationRate) = abi.decode(_ret, (uint256, uint256));
        return ((_newRatePerSec).toUint64(), (_newFullUtilizationRate).toUint64());
    }
}
