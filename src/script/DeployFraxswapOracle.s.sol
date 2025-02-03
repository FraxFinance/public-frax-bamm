// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import { BaseScript } from "frax-std/BaseScript.sol";
import { FraxswapOracle } from "src/contracts/FraxswapOracle.sol";

function deployFraxswapOracle() returns (FraxswapOracle iFraxswapOracle, address fraxswapOracle) {
    iFraxswapOracle = new FraxswapOracle();
    fraxswapOracle = address(iFraxswapOracle);
}

contract DeployFraxswapOracle is BaseScript {
    function run() public broadcaster {
        deployFraxswapOracle();
    }
}
