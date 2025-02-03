// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import "../../helpers/BAMMTestHelper.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";

contract BAMMFactoryTest is BAMMTestHelper {
    using Strings for uint256;

    address expectedOwner;

    function setUp() public virtual {
        defaultSetup();
        expectedOwner = address(this);
    }

    function test_initialState() public {
        _createFreshBamm();

        assertEq({ a: iBammFactory.routerMultihop(), b: routerMultihop, err: "routerMultihop incorrect" });
        assertEq({ a: address(iBammFactory.iFraxswapFactory()), b: pairFactory, err: "fraxswapFactory incorrect" });
        assertEq({ a: iBammFactory.fraxswapOracle(), b: oracle, err: "fraxswapOracle incorrect" });
        assertEq({
            a: iBammFactory.variableInterestRate(),
            b: variableInterestRate,
            err: "variableInterestRate incorrect"
        });

        assertEq({ a: iBammFactory.owner(), b: expectedOwner, err: "Owner not set" });
        assertEq({ a: iBammFactory.feeTo(), b: feeTo, err: "feeTo not set" });
    }

    function test_bammFactory_IRModel_setable_succeeds() public {
        (, address newVariableIRModel) = deployVariableInterestRate();

        vm.prank(iBammFactory.owner());
        iBammFactory.setBAMMVariableInterestRate(address(iBamm), newVariableIRModel);

        assertEq({
            a: address(iBamm.variableInterestRate()),
            b: newVariableIRModel,
            err: "// THEN: Bamm Variable Rate IR Model not expected"
        });
    }

    function test_bammFactory_maxOracleDiff_setable_succeeds() public {
        vm.prank(iBammFactory.owner());
        iBammFactory.setBammMaxOracleDiff(address(iBamm), 1000);

        assertEq({ a: iBamm.maxOracleDiff(), b: 1000, err: "// THEN: Bamm max oracle diff not expected" });
    }

    function test_bammFactory_IRModel_setable_reverts_notOwner() public {
        (, address newVariableIRModel) = deployVariableInterestRate();

        /// @notice owner is msg.sender
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", badActor));
        vm.prank(badActor);
        iBammFactory.setBAMMVariableInterestRate(address(iBamm), newVariableIRModel);
    }

    function test_bammFactory_maxOracleDiff_setable_reverts_notOwner() public {
        /// @notice owner is msg.sender
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", badActor));
        vm.prank(badActor);
        iBammFactory.setBammMaxOracleDiff(address(iBamm), 100e5);
    }
}
