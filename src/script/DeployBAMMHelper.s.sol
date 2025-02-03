// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import { BaseScript } from "frax-std/BaseScript.sol";
import { BAMMHelper } from "src/contracts/BAMMHelper.sol";

function deployBammHelper() returns (BAMMHelper iBammHelper, address bammHelper) {
    iBammHelper = new BAMMHelper();
    bammHelper = address(iBammHelper);
}

contract DeployBAMMHelper is BaseScript {
    function run() public broadcaster {
        deployBammHelper();
    }
}
