// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import { BaseScript } from "frax-std/BaseScript.sol";
import { VariableInterestRate } from "src/contracts/VariableInterestRate.sol";
import "../Constants.sol" as Constants;

function deployVariableInterestRate()
    returns (VariableInterestRate iVariableInterestRate, address variableInterestRate)
{
    uint256 FIFTY_BPS = 158_247_046;
    uint256 ONE_PERCENT = FIFTY_BPS * 2;
    bytes memory params = abi.encode(
        "Bamm [.05-7.30] 2 days (.725-.825)", // _suffix
        80_000, // _vertexUtilization
        90_000, // _vertex2Utilization
        200_000_000_000_000_000, // _vertexRatePercentOfDelta
        300_000_000_000_000_000, // _vertex2RatePercentOfDelta
        72_500, // _minUtil
        82_500, // _maxUtil
        ONE_PERCENT / 10, // _zeroUtilizationRate
        ONE_PERCENT * 5, // _minFullUtilizationRate
        ONE_PERCENT * 730, // _maxFullUtilizationRate
        172_800 // _rateHalfLife
    );
    iVariableInterestRate = new VariableInterestRate({ _params: params });
    variableInterestRate = address(iVariableInterestRate);
}

contract DeployVariableInterestRate is BaseScript {
    function run() public broadcaster {
        deployVariableInterestRate();
    }
}
