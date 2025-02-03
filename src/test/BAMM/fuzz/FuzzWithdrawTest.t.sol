// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import "../../BaseTest.t.sol";
import "../../helpers/BAMMTestHelper.sol";

contract FuzzWithdrawTest is BaseTest, BAMMTestHelper {
    /// @dev existing balance for token0/token1
    uint256 amount = 1e18;

    /// @dev balance trackers for assertions
    uint256 token0AmountTester = 0; // for clarity
    uint256 token1AmountTester = 0; // for clarity

    uint256 token0AmountVault = amount;
    uint256 token1AmountVault = amount;

    function setUp() public {
        defaultSetup();

        /// BACKGROUND: user has existing vault with token0 and token1 balances
        _bamm_deposit({
            _bamm: bamm,
            _token0: token0,
            _token1: token1,
            _user: tester,
            _token0Amount: int256(amount),
            _token1Amount: int256(amount)
        });
    }

    function testFuzz_Withdraw(
        uint256 token0AmountA,
        uint256 token1AmountA,
        uint256 token0AmountB,
        uint256 token1AmountB
    ) public {
        //==============================================================================
        // Arrange
        //==============================================================================

        /// GIVEN: basic amounts withdrawn
        token0AmountA = bound(token0AmountA, 0, amount);
        token1AmountA = bound(token1AmountA, 0, amount);
        token0AmountB = bound(token0AmountB, 0, amount);
        token1AmountB = bound(token1AmountB, 0, amount);

        /// GIVEN: cannot withdraw more than their balance
        vm.assume(token0AmountA + token0AmountB <= amount);
        vm.assume(token1AmountA + token1AmountB <= amount);

        /// GIVEN: increment account balances from withdraw (A)
        token0AmountTester += token0AmountA;
        token1AmountTester += token1AmountA;
        token0AmountVault -= token0AmountA;
        token1AmountVault -= token1AmountA;

        //==============================================================================
        // Act
        //==============================================================================

        /// WHEN: user withdraws (A) amounts from vault
        _bamm_withdraw({
            _bamm: bamm,
            _user: tester,
            _token0Amount: -(int256(token0AmountA)),
            _token1Amount: -(int256(token1AmountA))
        });

        //==============================================================================
        // Assert
        //==============================================================================

        _assertEqWithdrawals();

        //==============================================================================
        // Arrange
        //==============================================================================

        /// GIVEN: increment account balances from withdraw (A) and (B)
        token0AmountTester += token0AmountB;
        token1AmountTester += token1AmountB;
        token0AmountVault -= token0AmountB;
        token1AmountVault -= token1AmountB;

        //==============================================================================
        // Act
        //==============================================================================

        /// WHEN: user withdraws (B) amounts from vault
        _bamm_withdraw({
            _bamm: bamm,
            _user: tester,
            _token0Amount: -(int256(token0AmountB)),
            _token1Amount: -(int256(token1AmountB))
        });

        //==============================================================================
        // Assert
        //==============================================================================

        _assertEqWithdrawals();
    }

    function _assertEqWithdrawals() internal {
        assertEq({
            a: iToken0.balanceOf(tester),
            b: token0AmountTester,
            err: "tester did not receive token0 in withdrawal"
        });

        assertEq({
            a: iToken1.balanceOf(tester),
            b: token1AmountTester,
            err: "tester did not receive token1 in withdrawal"
        });

        assertEq({
            a: iToken0.balanceOf(bamm),
            b: token0AmountVault,
            err: "bamm did not transfer token0 in withdrawal"
        });

        assertEq({
            a: iToken1.balanceOf(bamm),
            b: token1AmountVault,
            err: "bamm did not transfer token1 in withdrawal"
        });

        (int256 vaultToken0, int256 vaultToken1, int256 rented) = iBamm.userVaults(tester);
        assertEq({ a: uint256(vaultToken0), b: token0AmountVault, err: "bamm vault.token0 balance incorrect" });

        assertEq({ a: uint256(vaultToken1), b: token1AmountVault, err: "bamm vault.token1 balance incorrect" });

        assertEq({ a: rented, b: 0, err: "bamm vault.rented should be 0" });
    }
}
