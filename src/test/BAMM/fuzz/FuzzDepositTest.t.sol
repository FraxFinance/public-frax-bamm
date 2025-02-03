// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import "../../BaseTest.t.sol";
import "../../helpers/BAMMTestHelper.sol";

contract FuzzDepositTest is BaseTest, BAMMTestHelper {
    uint256 token0Amount;
    uint256 token1Amount;

    function setUp() public {
        defaultSetup();
    }

    function testFuzz_Deposit(
        uint256 token0AmountA,
        uint256 token1AmountA,
        uint256 token0AmountB,
        uint256 token1AmountB
    ) public {
        //==============================================================================
        // Arrange
        //==============================================================================

        /// GIVEN: basic amounts deposited
        token0AmountA = bound(token0AmountA, 0, 1e18);
        token1AmountA = bound(token1AmountA, 0, 1e18);
        token0AmountB = bound(token0AmountB, 0, 1e18);
        token1AmountB = bound(token1AmountB, 0, 1e18);

        /// GIVEN: token0Amount and token1Amount incremented to track deposit (A)
        token0Amount += token0AmountA;
        token1Amount += token1AmountA;

        //==============================================================================
        // Act
        //==============================================================================

        /// WHEN: user deposits (A) amounts into the vault
        _bamm_deposit({
            _bamm: bamm,
            _token0: token0,
            _token1: token1,
            _user: freshUser,
            _token0Amount: int256(token0AmountA),
            _token1Amount: int256(token1AmountA)
        });

        //==============================================================================
        // Assert
        //==============================================================================

        _assertEqDeposits();

        //==============================================================================
        // Arrange
        //==============================================================================

        /// GIVEN: token0Amount and token1Amount incremented to track deposit (A) and (B)
        token0Amount += token0AmountB;
        token1Amount += token1AmountB;

        //==============================================================================
        // Act
        //==============================================================================

        /// WHEN: user deposits (B) amounts into the vault
        _bamm_deposit({
            _bamm: bamm,
            _token0: token0,
            _token1: token1,
            _user: freshUser,
            _token0Amount: int256(token0AmountB),
            _token1Amount: int256(token1AmountB)
        });

        //==============================================================================
        // Assert
        //==============================================================================

        _assertEqDeposits();
    }

    function _assertEqDeposits() internal {
        assertEq({ a: iToken0.balanceOf(freshUser), b: 0, err: "freshUser did not transfer token0 in deposit" });

        assertEq({ a: iToken1.balanceOf(freshUser), b: 0, err: "freshUser did not transfer token1 in deposit" });

        assertEq({ a: iToken0.balanceOf(bamm), b: token0Amount, err: "bamm did not receive token0 in deposit" });

        assertEq({ a: iToken1.balanceOf(bamm), b: token1Amount, err: "bamm did not receive token1 in deposit" });

        (int256 vaultToken0, int256 vaultToken1, int256 rented) = iBamm.userVaults(freshUser);
        assertEq({ a: uint256(vaultToken0), b: token0Amount, err: "bamm vault.token0 balance incorrect" });

        assertEq({ a: uint256(vaultToken1), b: token1Amount, err: "bamm vault.token1 balance incorrect" });

        assertEq({ a: rented, b: 0, err: "bamm vault.rented should be 0" });
    }
}
