// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import "../../BaseTest.t.sol";
import "../../helpers/BAMMTestHelper.sol";

contract WithdrawTest is BaseTest, BAMMTestHelper {
    function setUp() public virtual {
        defaultSetup();

        /// BACKGROUND: user deposits token0 & token1
        _bamm_deposit({
            _bamm: bamm,
            _token0: token0,
            _token1: token1,
            _user: tester,
            _token0Amount: 1e18,
            _token1Amount: 1e18
        });
    }

    function test_Withdraw_BothTokens_succeeds() public {
        uint256 amount = 1e12;
        IBAMM.Action memory action;
        action.token0Amount = -int128(int256(amount));
        action.token1Amount = -int128(int256(amount));
        action.to = tester;

        uint256 balanceOfToken0Before = iToken0.balanceOf(tester);
        uint256 balanceOfToken1Before = iToken1.balanceOf(tester);

        vm.prank(tester);
        iBamm.executeActions(action);

        assertEq(iToken0.balanceOf(tester), balanceOfToken0Before + amount);
        assertEq(iToken1.balanceOf(tester), balanceOfToken1Before + amount);
    }

    function test_Withdraw_token0_CannotWithdrawToSelf_reverts() public {
        IBAMM.Action memory action;
        action.token0Amount = -1e12;
        action.to = bamm;

        vm.expectRevert(IBAMM.CannotWithdrawToSelf.selector);
        vm.prank(tester);
        iBamm.executeActions(action);
    }

    function test_Withdraw_token0_AfterSomeoneElseDeposits_succeeds() public {
        _bamm_deposit({
            _bamm: bamm,
            _token0: token0,
            _token1: token1,
            _user: tester2,
            _token0Amount: 1e18,
            _token1Amount: 1e18
        });

        assertEq(iToken0.balanceOf(tester), 0);

        IBAMM.Action memory action;
        action.token0Amount = -1e12;
        action.to = tester;

        vm.prank(tester);
        iBamm.executeActions(action);

        (int256 token0Vault, , ) = iBamm.userVaults(tester);
        (int256 token0Vault2, , ) = iBamm.userVaults(tester2);

        assertEq(iToken0.balanceOf(tester), uint256(-action.token0Amount));
        assertEq(1e18 - uint256(-action.token0Amount), uint256(token0Vault));
        assertEq(iToken0.balanceOf(bamm), uint256(token0Vault + token0Vault2));
    }

    function test_Withdraw_token0_NoVault_reverts() public {
        IBAMM.Action memory action;
        action.token0Amount = -1e12;
        action.to = badActor;

        vm.expectRevert(IBAMM.NotSolvent.selector);
        vm.prank(badActor);
        iBamm.executeActions(action);
    }

    function test_Withdraw_token0_TooMuch_reverts() public {
        IBAMM.Action memory action;
        action.token0Amount = -1.0e28;
        action.to = tester;

        vm.prank(tester);
        vm.expectRevert();
        iBamm.executeActions(action);
    }

    function test_Withdraw_token0_TooMuchBeforeSomeoneElseReDeposits_reverts() public {
        deal(token0, bamm, 100e28);

        IBAMM.Action memory action;
        action.token0Amount = -1.0e28;
        action.to = tester;

        vm.prank(tester);
        vm.expectRevert(IBAMM.NotSolvent.selector);
        iBamm.executeActions(action);
    }

    function test_Withdraw_token0_TooMuchAfterSomeoneElseReDeposits_reverts() public {
        _bamm_deposit({
            _bamm: bamm,
            _token0: token0,
            _token1: token1,
            _user: tester2,
            _token0Amount: 1e28,
            _token1Amount: 1e28
        });

        IBAMM.Action memory action;
        action.token0Amount = -1.0e28;
        action.to = tester;

        vm.prank(tester);
        vm.expectRevert(IBAMM.NotSolvent.selector);
        iBamm.executeActions(action);
    }

    function test_Withdraw_token1_CannotWithdrawToSelf_reverts() public {
        IBAMM.Action memory action;
        action.token1Amount = -1e12;
        action.to = bamm;

        vm.expectRevert(IBAMM.CannotWithdrawToSelf.selector);
        vm.prank(tester);
        iBamm.executeActions(action);
    }

    function test_Withdraw_token1_AfterSomeoneElseDeposits_succeeds() public {
        _bamm_deposit({
            _bamm: bamm,
            _token0: token0,
            _token1: token1,
            _user: tester2,
            _token0Amount: 1e18,
            _token1Amount: 1e18
        });

        assertEq(iToken0.balanceOf(tester), 0);

        IBAMM.Action memory action;
        action.token1Amount = -1e12;
        action.to = tester;

        vm.prank(tester);
        iBamm.executeActions(action);

        (, int256 token1Vault, ) = iBamm.userVaults(tester);
        (, int256 token1Vault2, ) = iBamm.userVaults(tester2);

        assertEq(iToken1.balanceOf(tester), uint256(-action.token1Amount));
        assertEq(1e18 - uint256(-action.token1Amount), uint256(token1Vault));
        assertEq(iToken1.balanceOf(bamm), uint256(token1Vault + token1Vault2));
    }

    function test_Withdraw_token1_NoVault_reverts() public {
        IBAMM.Action memory action;
        action.token1Amount = -1e12;
        action.to = badActor;

        vm.expectRevert(IBAMM.NotSolvent.selector);
        vm.prank(badActor);
        iBamm.executeActions(action);
    }

    function test_Withdraw_token1_TooMuch_reverts() public {
        IBAMM.Action memory action;
        action.token1Amount = -1.0e28;
        action.to = tester;

        vm.prank(tester);
        vm.expectRevert(bytes4(keccak256("FailedInnerCall()")));
        iBamm.executeActions(action);
    }

    function test_Withdraw_token1_TooMuchBeforeSomeoneElseReDeposits_reverts() public {
        deal(token1, bamm, 100e28);

        IBAMM.Action memory action;
        action.token1Amount = -1.0e28;
        action.to = tester;

        vm.prank(tester);
        vm.expectRevert(IBAMM.NotSolvent.selector);
        iBamm.executeActions(action);
    }

    function test_Withdraw_token1_TooMuchAfterSomeoneElseReDeposits_reverts() public {
        _bamm_deposit({
            _bamm: bamm,
            _token0: token0,
            _token1: token1,
            _user: tester2,
            _token0Amount: 1e28,
            _token1Amount: 1e28
        });

        IBAMM.Action memory action;
        action.token1Amount = -1.0e28;
        action.to = tester;

        vm.prank(tester);
        vm.expectRevert(IBAMM.NotSolvent.selector);
        iBamm.executeActions(action);
    }
}
