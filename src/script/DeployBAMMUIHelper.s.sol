// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { BaseScript } from "frax-std/BaseScript.sol";
import { BAMMUIHelper } from "src/contracts/BAMMUIHelper.sol";

function deployBAMMUIHelper() returns (BAMMUIHelper iBammUIHelper, address bammUIHelper) {
    iBammUIHelper = new BAMMUIHelper();
    bammUIHelper = address(iBammUIHelper);
}

contract DeployBAMMUIHelper is BaseScript {
    function run() public broadcaster {
        deployBAMMUIHelper();
    }
}
