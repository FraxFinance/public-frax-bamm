// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import { BaseScript } from "frax-std/BaseScript.sol";
import "src/Constants.sol" as Constants;

import { BAMM, BAMMFactory, deployBammFactory } from "../DeployBAMMFactory.s.sol";
import { deployVariableInterestRate } from "../DeployVariableInterestRate.s.sol";

import { FraxswapOracle } from "src/contracts/FraxswapOracle.sol";

contract DeployBAMMProtocolFraxtal is BaseScript {
    function run() public broadcaster {
        address fraxswapOracle = address(new FraxswapOracle());
        (, address variableInterestRate) = deployVariableInterestRate();

        // deploy factory
        deployBammFactory({
            _fraxswapFactory: 0xE30521fe7f3bEB6Ad556887b50739d6C7CA667E6,
            _routerMultihop: 0x46D2487CdbeA04411C49e6c55aCE805bfA8f5dE5,
            _fraxswapOracle: fraxswapOracle,
            _variableInterestRate: variableInterestRate,
            _feeTo: 0xb0E1650A9760e0f383174af042091fc544b8356f // frax deployer
        });
    }
}
