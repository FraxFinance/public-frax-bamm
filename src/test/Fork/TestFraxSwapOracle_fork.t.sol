// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "../BaseTest.t.sol";
import "../helpers/BAMMTestHelper.sol";
import { OracleCummulativePriceOverflowTest } from "src/test/FraxswapOracle/PriceCumulativeOverflow.t.sol";

contract TestOracleCumulativeOverflowTest is OracleCummulativePriceOverflowTest {
    function setUp() public override {
        defaultSetup();
    }

    function defaultSetup() internal override {
        vm.createSelectFork(vm.envString("FRAXTAL_MAINNET_URL"), 13_480_710);
        pairFactory = 0xE30521fe7f3bEB6Ad556887b50739d6C7CA667E6;

        bamm = 0xBA082D3ef4d27d31c49f05dd8F096A236c0f7069;
        bammErc20 = 0x37416992335D09875Ce4cb186E3A04DceE9c6858;

        oracle = 0x3B1d8484b7036f62feD9D5EaE15B186Bd7C3E8b4;
        bammFactory = 0x19928170D739139bfbBb6614007F8EEeD17DB0Ba;
        variableInterestRate = 0x5eFcE1D6C8A71870Ee5b6850CaAe64405bA509C6;

        iBammOracle = FraxswapOracle(oracle);
        iBammFactory = BAMMFactory(bammFactory);
        iVariableInterestRate = VariableInterestRate(variableInterestRate);

        iBammErc20 = BAMMERC20(bammErc20);
        iBamm = BAMM(bamm);
    }
}
