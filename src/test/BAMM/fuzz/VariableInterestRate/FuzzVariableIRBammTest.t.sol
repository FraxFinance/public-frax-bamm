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

    function test_varableRateContractName() public {
        assertEq({
            a: iVariableInterestRate.name(),
            b: "Variable Rate V3 Bamm [.05-7.30] 2 days (.725-.825)",
            err: "// THEN: VaraibleRateIR name not as expected"
        });
    }

    function testVariableRateBammRateEquivalency(
        uint16 _deltaTime,
        uint32 _utilization,
        uint64 _oldFullUtilizationRate
    ) public {
        // Bound oldFullUtil variable between max and min allowed
        _oldFullUtilizationRate = uint64(
            bound(
                _oldFullUtilizationRate,
                iVariableInterestRate.MIN_FULL_UTIL_RATE(),
                iVariableInterestRate.MAX_FULL_UTIL_RATE()
            )
        );

        // Load the specified oldFullUtil and timeSinceLastInterestPayment into BAMM contract storage
        vm.store(address(iBamm), bytes32(uint256(4)), bytes32(uint256(block.timestamp - _deltaTime)));
        vm.store(address(iBamm), bytes32(uint256(5)), bytes32(uint256(_oldFullUtilizationRate)));

        // Bound the utilization by the by the min and max values specific to BAMM
        uint256 utilization = bound(_utilization, 0.01e5, 1e5);

        /// @notice util bamm represented 1e18 with a max of MAX_UTILITY_RATE
        uint256 utilBamm = (utilization * iBamm.MAX_UTILITY_RATE()) / 1e5;
        uint256 rate = iBamm.previewInterestRate(utilBamm);

        (uint256 _newRate, ) = iVariableInterestRate.getNewRate(_deltaTime, utilization, _oldFullUtilizationRate);

        assertEq(rate, _newRate);
    }

    function testVariableRateImplementationJSEquivalency(
        uint16 _deltaTime,
        uint32 _utilization,
        uint64 _oldFullUtilizationRate
    ) public {
        // Bound oldFullUtil variable between max and min allowed
        _oldFullUtilizationRate = uint64(
            bound(
                _oldFullUtilizationRate,
                iVariableInterestRate.MIN_FULL_UTIL_RATE(),
                iVariableInterestRate.MAX_FULL_UTIL_RATE()
            )
        );

        // Load the specified oldFullUtil and timeSinceLastInterestPayment into BAMM contract storage
        vm.store(address(iBamm), bytes32(uint256(4)), bytes32(uint256(block.timestamp - _deltaTime)));
        vm.store(address(iBamm), bytes32(uint256(5)), bytes32(uint256(_oldFullUtilizationRate)));

        // // Bound the utilization by the by the min and max values specific to BAMM
        uint256 utilization = bound(_utilization, 1, 1e5);

        /// @notice util bamm represented 1e18 with a max of MAX_UTILITY_RATE
        uint256 utilBamm = (utilization * iBamm.MAX_UTILITY_RATE()) / 1e5;
        uint256 rate = iBamm.previewInterestRate(utilBamm);

        (uint256 _expectedRate, uint256 _expectedMaxRate) = iVariableInterestRate.__interestCalculator(
            _deltaTime,
            utilization,
            _oldFullUtilizationRate,
            vm
        );
        console.log("The utilization rate: ", utilBamm, utilization);
        console.log(rate, _expectedRate * 3_153_600_000);
        console.log(_expectedMaxRate);
        assertApproxEqRel(uint256(rate), uint256(_expectedRate), 1e16);
    }
}
