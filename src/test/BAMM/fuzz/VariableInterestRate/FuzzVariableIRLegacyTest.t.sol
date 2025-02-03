// SPDX-License-Identifier: ISC
pragma solidity 0.8.23;

import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import "src/test/BaseTest.t.sol";
import "src/contracts/VariableInterestRate.sol";
import "src/test/helpers/VariableRateHelper.sol";

contract TestVariableRate is BaseTest {
    using Strings for uint256;
    using SafeCast for *;
    using RateHelper for *;

    function setUp() public {
        defaultSetup();
    }

    function testFuzzyVariableRateRounding(
        uint64 _oldFullUtilizationRate,
        uint16 _deltaTime,
        uint32 _utilization
    ) public {
        _utilization = uint32(StdUtils.bound(_utilization, 1, 1e5));
        vm.assume(_deltaTime > 0);
        _oldFullUtilizationRate = bound(_oldFullUtilizationRate, DEFAULT_MIN_INTEREST, DEFAULT_MAX_INTEREST).toUint64();
        _testVariableRateRounding(_deltaTime, _utilization, _oldFullUtilizationRate);
    }

    function testFuzzyVariableRateInvariants(
        uint64 _oldFullUtilizationRate,
        uint16 _deltaTime,
        uint32 _utilization
    ) public {
        _utilization = (_utilization % 1e5) + 1;
        vm.assume(_deltaTime > 0);
        _oldFullUtilizationRate = bound(
            _oldFullUtilizationRate,
            iVariableInterestRate.MIN_FULL_UTIL_RATE(),
            iVariableInterestRate.MAX_FULL_UTIL_RATE()
        ).toUint64();
        _testVariableRateInvariants(_deltaTime, _utilization, _oldFullUtilizationRate);
    }

    function testVariableRate() public {
        _testVariableRateRounding(1637, 86_542, 146_090_229_566);
    }

    function testFuzzVariableIRInputs(uint64 _oldFullUtilizationRate, uint256 _deltaTime, uint256 _utilization) public {
        _oldFullUtilizationRate = bound(
            _oldFullUtilizationRate,
            iVariableInterestRate.MIN_FULL_UTIL_RATE(),
            iVariableInterestRate.MAX_FULL_UTIL_RATE()
        ).toUint64();
        vm.assume(_utilization < 200e5); // 200 * 100%
        vm.assume(_deltaTime < 5 * 365 days);
        (uint256 _newRate, uint256 newFull) = iVariableInterestRate.getNewRate(
            _deltaTime,
            _utilization,
            uint64(_oldFullUtilizationRate)
        );
    }

    // testVariableRate
    function _testVariableRateRounding(uint16 _deltaTime, uint32 _utilization, uint64 _oldFullUtilizationRate) public {
        (uint256 _newRate, uint256 _newMaxRate) = iVariableInterestRate.getNewRate(
            _deltaTime,
            _utilization,
            _oldFullUtilizationRate
        );

        (uint64 _expectedRate, uint64 _expectedMaxRate) = iVariableInterestRate.__interestCalculator(
            _deltaTime,
            _utilization,
            _oldFullUtilizationRate,
            vm
        );
        assertApproxEqRel(uint256(_expectedRate), uint256(_newRate), 1e16);
        assertApproxEqRel(uint256(_expectedMaxRate), uint256(_newMaxRate), 1e16);
    }

    function _testVariableRateInvariants(
        uint16 _deltaTime,
        uint32 _utilization,
        uint64 _oldFullUtilizationRate
    ) public {
        (uint256 _newRate, uint256 _newMaxRate) = iVariableInterestRate.getNewRate(
            _deltaTime,
            _utilization,
            _oldFullUtilizationRate
        );
        uint256 _vertexRate = ((iVariableInterestRate.VERTEX_RATE_PERCENT() *
            (_newMaxRate - iVariableInterestRate.ZERO_UTIL_RATE())) / 1e18) + iVariableInterestRate.ZERO_UTIL_RATE();
        assertGt(_vertexRate, iVariableInterestRate.ZERO_UTIL_RATE(), "vertexRate > zeroUtilRate");
        assertLt(_vertexRate, _newMaxRate, "newMaxRate > vertexRate");
        assertGe(_newRate, iVariableInterestRate.ZERO_UTIL_RATE(), "newRate >= zeroUtilizationRate");
        assertGe(_newMaxRate, iVariableInterestRate.ZERO_UTIL_RATE(), "newMaxRate >= zeroUtilizationRate");
        assertGe(_newMaxRate, iVariableInterestRate.MIN_FULL_UTIL_RATE(), "newMaxRate >= minFullUtilRate");
    }
}
