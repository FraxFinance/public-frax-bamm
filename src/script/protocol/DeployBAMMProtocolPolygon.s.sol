// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import { BaseScript } from "frax-std/BaseScript.sol";
import "src/Constants.sol" as Constants;

import { BAMM, BAMMFactory, deployBammFactory } from "../DeployBAMMFactory.s.sol";

import { FraxswapOracle } from "src/contracts/FraxswapOracle.sol";
import { FraxswapDummyRouter } from "src/contracts/FraxswapDummyRouter.sol";

import { IWETH } from "@uniswap/v2-periphery/contracts/interfaces/IWETH.sol";

contract DeployBAMMProtocolPolygon is BaseScript {
    function run() public broadcaster {
        // deploy fraxswap oracle
        address fraxswapOracle = address(new FraxswapOracle());

        // deploy factory
        (BAMMFactory iBammFactory, ) = deployBammFactory({
            _fraxswapFactory: 0x54F454D747e037Da288dB568D4121117EAb34e79,
            _routerMultihop: 0x68E986Ac0409bf59E08bF417D2c160a5d4598e41,
            _fraxswapOracle: fraxswapOracle,
            _variableInterestRate: address(0),
            _feeTo: address(0)
        });
        iBammFactory.setCreationCode(type(BAMM).creationCode);
    }
}
