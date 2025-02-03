// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "src/test/BaseTest.t.sol";
import { MintTest } from "src/test/BAMM/unit/MintTest.t.sol";

contract MintTestFork is MintTest {
    function setUp() public override {
        defaultSetup();

        deal(address(iBamm.token0()), address(tester), 10_000e18);
        deal(address(iBamm.token1()), address(tester), 10_000e18);
        deal(address(iBamm.token0()), address(tester2), 100e18);
        deal(address(iBamm.token1()), address(tester2), 100e18);
        deal(address(iBamm.token0()), address(freshUser), 100e18);
        deal(address(iBamm.token1()), address(freshUser), 100e18);

        vm.startPrank(tester);
        iBamm.token0().transfer(address(iBamm.pair()), 100e18);
        iBamm.token1().transfer(address(iBamm.pair()), 100e18);
        iBamm.pair().mint(tester);
        vm.startPrank(tester2);
        iBamm.token0().transfer(address(iBamm.pair()), 100e18);
        iBamm.token1().transfer(address(iBamm.pair()), 100e18);
        iBamm.pair().mint(tester2);
        vm.stopPrank();

        deal(address(pair), tester, 11e18);
        deal(address(pair), tester, 11e18);

        deal(address(pair), tester2, 10e18);
        deal(address(pair), tester2, 10e18);

        // Note: unbacked minting of LP done before bamm share price init
        //       consequently all invariants hold
    }

    function defaultSetup() internal override {
        vm.createSelectFork(vm.envString("FRAXTAL_MAINNET_URL"), 13_480_710);

        pairFactory = 0xE30521fe7f3bEB6Ad556887b50739d6C7CA667E6;

        bamm = 0xBA082D3ef4d27d31c49f05dd8F096A236c0f7069;
        bammErc20 = 0x37416992335D09875Ce4cb186E3A04DceE9c6858;

        oracle = 0x3B1d8484b7036f62feD9D5EaE15B186Bd7C3E8b4;
        bammFactory = 0x19928170D739139bfbBb6614007F8EEeD17DB0Ba;
        variableInterestRate = 0x5eFcE1D6C8A71870Ee5b6850CaAe64405bA509C6;

        iBammUIHelper = BAMMUIHelper(0xb16F68C7351BBF8491824e7971EFa14d2Fa0885A);

        iBammOracle = FraxswapOracle(oracle);
        iBammFactory = BAMMFactory(bammFactory);
        routerMultihop = iBammFactory.routerMultihop();
        iVariableInterestRate = VariableInterestRate(variableInterestRate);

        iBammErc20 = BAMMERC20(bammErc20);
        iBamm = BAMM(bamm);

        tester = payable(address(0xFFFFF123));
        tester2 = payable(address(0xEEEEEEE123));
        feeTo = iBammFactory.feeTo();
        pair = address(iBamm.pair());
        iPair = IFraxswapPair(pair);
        iToken0 = iBamm.token0();
        iToken1 = iBamm.token1();
        token0 = address(iToken0);
        token1 = address(iToken1);
    }
}
