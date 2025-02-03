// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import { BaseScript } from "frax-std/BaseScript.sol";
import { BAMM, BAMMFactory } from "src/contracts/factories/BAMMFactory.sol";
import "src/Constants.sol" as Constants;

function deployBammFactory(
    address _fraxswapFactory,
    address _routerMultihop,
    address _fraxswapOracle,
    address _variableInterestRate,
    address _feeTo
) returns (BAMMFactory iBammFactory, address bammFactory) {
    iBammFactory = new BAMMFactory({
        _fraxswapFactory: _fraxswapFactory,
        _routerMultihop: _routerMultihop,
        _fraxswapOracle: _fraxswapOracle,
        _variableInterestRate: _variableInterestRate,
        _feeTo: _feeTo
    });
    bammFactory = address(iBammFactory);
    iBammFactory.setCreationCode(type(BAMM).creationCode);
}

contract DeployBammFactory is BaseScript {
    function run() public broadcaster {
        deployBammFactory({
            _fraxswapFactory: address(0),
            _routerMultihop: address(0),
            _fraxswapOracle: address(0),
            _variableInterestRate: address(0),
            _feeTo: address(0)
        });
    }
}
