// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import "../../helpers/BAMMTestHelper.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";

contract BAMMTest is BAMMTestHelper {
    using Strings for uint256;

    function setUp() public virtual {
        defaultSetup();
    }

    function test_initialState() public virtual {
        _createFreshBamm();

        assertEq({ a: iBamm.factory(), b: bammFactory, err: "factory incorrect" });

        assertEq({ a: address(iBamm.token0()), b: token0, err: "token0 incorrect" });
        assertEq({ a: address(iBamm.token1()), b: token1, err: "token1 incorrect" });
        assertEq({ a: address(iBamm.routerMultihop()), b: routerMultihop, err: "routerMultihop incorrect" });
        assertEq({ a: address(iBamm.fraxswapOracle()), b: oracle, err: "fraxswapOracle incorrect" });
        assertEq({
            a: address(iBamm.variableInterestRate()),
            b: variableInterestRate,
            err: "variableInterestRate incorrect"
        });

        (uint256 major, uint256 minor, uint256 patch) = iBamm.version();
        assertEq({ a: major, b: 0, err: "// THEN: major version not expected" });
        assertEq({ a: minor, b: 5, err: "// THEN: minor version not expected" });
        assertEq({ a: patch, b: 2, err: "// THEN: patch version not expected" });
    }

    function test_ltv_nonInitializedUser_returns0() public {
        _createFreshBamm();
        uint256 res = ltv(alice);
        assertEq(res, 0);
    }

    function test_bamm_IRModel_settable_reverts_notFactory() public {
        (, address newVariableIRModel) = deployVariableInterestRate();

        vm.expectRevert(IBAMM.NotFactory.selector);
        iBamm.setVariableInterestRate(newVariableIRModel);
    }

    function test_bamm_maxOracleDiff_settable_reverts_notFactory() public {
        vm.expectRevert(IBAMM.NotFactory.selector);
        iBamm.setMaxOracleDeviation(100e5);
    }

    function test_addInterest_empty() public {
        iBamm.addInterest();
    }
}
