// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import "../../helpers/BAMMTestHelper.sol";

contract FuzzRentTest is BAMMTestHelper {
    uint256 totalAvailableToRent;
    uint256 lpMinted;

    function setUp() public {
        defaultSetup();
        lpMinted = iPair.balanceOf(tester);
        _bamm_mint({ _bamm: bamm, _user: tester, _to: tester, _pair: pair, _amountPair: lpMinted });
        /// @notice `_calculateLPToBamm` can be called after mint given `sqrtRentedReal` = 0
        totalAvailableToRent = _calculateLPToBamm(lpMinted);
    }

    struct RentMath {
        uint256 rentToRepay;
        int256 token0;
        int256 token1;
        int256 rented;
        uint256 lpBammBefore;
        uint256 lpBammAfter;
        uint256 lpOwed;
        uint256 token0amt;
        uint256 token1amt;
        uint256 expToken0Remaining;
        uint256 expToken1Remaining;
    }

    function testFuzzRentPositive(uint256 rentAmount) public {
        //==============================================================================
        // Arrange
        //==============================================================================
        // GIVEN: user has open vault w/ sufficient liquidity

        /// @notice Given `rentMultiplier`: 1e18 bamm token amount is equivalent to available rent
        uint256 maxRent = ((totalAvailableToRent * 9) / 10);
        rentAmount = bound(rentAmount, 1e5, maxRent);
        _bamm_deposit({
            _bamm: bamm,
            _token0: token0,
            _token1: token1,
            _user: tester2,
            _token0Amount: 300e18,
            _token1Amount: 300e18
        });

        //==============================================================================
        // Act
        //==============================================================================
        uint256 lpToRentInitial = _calculateLpFromRent(rentAmount, false);
        (uint256 token0Owed, uint256 token1Owed) = _calculateTokensFromLp(lpToRentInitial, false);

        // WHEN: user rents lp from bamm
        _bamm_rent({ _bamm: bamm, _user: tester2, _rent: int256(rentAmount) });

        //==============================================================================
        // Assert
        //==============================================================================
        vm.warp(block.timestamp + 30 days);
        iBamm.addInterest();
        uint256 lpToRentAccrued = _calculateLpFromRent(rentAmount, false);

        assertGt({
            a: lpToRentAccrued,
            b: lpToRentInitial,
            err: "// THEN: lp:rent has not increased as interest accrues"
        });
        assertEq({
            a: token0Owed + 300e18,
            b: iToken0.balanceOf(bamm),
            err: "// THEN: token0 balance of bamm not expected"
        });
        assertEq({
            a: token1Owed + 300e18,
            b: iToken1.balanceOf(bamm),
            err: "// THEN: token0 balance of bamm not expected"
        });
    }

    function testFuzzRentPositive_freshPool(uint256 rentAmount) public {
        //==============================================================================
        // Arrange
        //==============================================================================
        // GIVEN: user has open vault w/ sufficient liquidity, on a fresh pool
        _createFreshBamm();
        lpMinted = iPair.balanceOf(tester);
        _bamm_mint({ _bamm: bamm, _user: tester, _to: tester, _pair: pair, _amountPair: lpMinted });

        totalAvailableToRent = _calculateLPToBamm(lpMinted);
        uint256 maxRent = ((totalAvailableToRent * 9) / 10);
        rentAmount = bound(rentAmount, 1e5, maxRent);

        _bamm_deposit({
            _bamm: bamm,
            _token0: token0,
            _token1: token1,
            _user: tester2,
            _token0Amount: 100e18,
            _token1Amount: 100e18
        });

        //==============================================================================
        // Act
        //==============================================================================
        uint256 lpToRentInitial = _calculateLpFromRent(rentAmount, false);
        (uint256 token0Owed, uint256 token1Owed) = _calculateTokensFromLp(lpToRentInitial, false);

        // WHEN: user rents lp from bamm
        _bamm_rent({ _bamm: bamm, _user: tester2, _rent: int256(rentAmount) });

        //==============================================================================
        // Assert
        //==============================================================================
        vm.warp(block.timestamp + 30 days);
        iBamm.addInterest();
        uint256 lpToRentAccrued = _calculateLpFromRent(rentAmount, false);

        assertGt({
            a: lpToRentAccrued,
            b: lpToRentInitial,
            err: "// THEN: lp:rent has not increased as interest accrues"
        });
        assertEq({
            a: token0Owed + 100e18,
            b: iToken0.balanceOf(bamm),
            err: "// THEN: token0 balance of bamm not expected"
        });
        assertEq({
            a: token1Owed + 100e18,
            b: iToken1.balanceOf(bamm),
            err: "// THEN: token0 balance of bamm not expected"
        });
    }

    function testFuzzRentNegative(uint256 rentAmount) public {
        RentMath memory rentMath;

        //==============================================================================
        // Arrange
        //==============================================================================
        // GIVEN: user has open vault w/ sufficient liquidity & + rent outstanding

        testFuzzRentPositive(rentAmount);

        /// @notice Given `rentMultiplier`: 1e18 bamm token amount is equivalent to available rent
        uint256 maxRent = ((totalAvailableToRent * 9) / 10);
        rentAmount = bound(rentAmount, 1e5, maxRent);
        rentMath.rentToRepay = rentAmount / 2;
        (rentMath.token0, rentMath.token1, rentMath.rented) = iBamm.userVaults(tester2);

        rentMath.lpBammBefore = iPair.balanceOf(bamm);

        //==============================================================================
        // Act
        //==============================================================================
        uint256 lpOwed = _calculateLpFromRent(rentMath.rentToRepay, true);
        (uint256 token0amt, uint256 token1amt) = _calculateTokensFromLp(lpOwed, true);

        rentMath.expToken0Remaining = uint256(rentMath.token0) - token0amt;
        rentMath.expToken1Remaining = uint256(rentMath.token1) - token1amt;

        // WHEN: user repays a portion of their rent
        _bamm_rent({ _bamm: bamm, _user: tester2, _rent: -int256(rentMath.rentToRepay) });

        //==============================================================================
        // Assert
        //==============================================================================
        rentMath.lpBammAfter = iPair.balanceOf(bamm);
        (int256 token0InVault, int256 token1InVault, int256 rentedInVault) = iBamm.userVaults(tester2);

        assertEq({
            a: rentMath.expToken0Remaining,
            b: uint256(token0InVault),
            err: "// THEN: token0 vault balance not expected"
        });
        assertEq({
            a: rentMath.expToken1Remaining,
            b: uint256(token1InVault),
            err: "// THEN: token1 vault balance not expected"
        });
        assertEq({
            a: lpOwed,
            b: rentMath.lpBammAfter - rentMath.lpBammBefore,
            err: "// THEN: lp balance of bamm is not expected"
        });
        assertEq({
            a: uint256(rentedInVault),
            b: rentAmount - rentMath.rentToRepay,
            err: "// THEN: rented amount not expected"
        });
        assertEq({
            a: iToken0.balanceOf(bamm),
            b: uint256(token0InVault),
            err: "// THEN: Bamm balanceOf does not match tokens in vault"
        });
        assertEq({
            a: iToken1.balanceOf(bamm),
            b: uint256(token1InVault),
            err: "// THEN: bamm balanceOf does not match tokens in vault"
        });
    }

    function testFuzzRentNegative_freshPool(uint256 rentAmount) public {
        RentMath memory rentMath;

        //==============================================================================
        // Arrange
        //==============================================================================
        // GIVEN: user has open vault w/ sufficient liquidity & + rent, on a fresh pool
        _createFreshBamm();
        lpMinted = iPair.balanceOf(tester);
        _bamm_mint({ _bamm: bamm, _user: tester, _to: tester, _pair: pair, _amountPair: lpMinted });
        totalAvailableToRent = _calculateLPToBamm(lpMinted);
        testFuzzRentPositive(rentAmount);
        /// @notice Given `rentMultiplier`: 1e18 bamm token amount is equivalent to available rent
        uint256 maxRent = ((totalAvailableToRent * 9) / 10);
        rentAmount = bound(rentAmount, 1e5, maxRent);
        rentMath.rentToRepay = rentAmount / 2;
        (rentMath.token0, rentMath.token1, rentMath.rented) = iBamm.userVaults(tester2);

        rentMath.lpBammBefore = iPair.balanceOf(bamm);

        //==============================================================================
        // Act
        //==============================================================================
        rentMath.lpOwed = _calculateLpFromRent(rentMath.rentToRepay, true);
        (rentMath.token0amt, rentMath.token1amt) = _calculateTokensFromLp(rentMath.lpOwed, true);

        rentMath.expToken0Remaining = uint256(rentMath.token0) - rentMath.token0amt;
        rentMath.expToken1Remaining = uint256(rentMath.token1) - rentMath.token1amt;

        // WHEN: user repays a portion of their rent
        _bamm_rent({ _bamm: bamm, _user: tester2, _rent: -int256(rentMath.rentToRepay) });

        //==============================================================================
        // Assert
        //==============================================================================
        rentMath.lpBammAfter = iPair.balanceOf(bamm);
        (int256 token0InVault, int256 token1InVault, int256 rentedInVault) = iBamm.userVaults(tester2);

        assertEq({
            a: rentMath.expToken0Remaining,
            b: uint256(token0InVault),
            err: "// THEN: token0 vault balance not expected"
        });
        assertEq({
            a: rentMath.expToken1Remaining,
            b: uint256(token1InVault),
            err: "// THEN: token1 vault balance not expected"
        });
        assertEq({
            a: rentMath.lpOwed,
            b: rentMath.lpBammAfter - rentMath.lpBammBefore,
            err: "// THEN: lp balance of bamm is not expected"
        });
        assertEq({
            a: uint256(rentedInVault),
            b: rentAmount - rentMath.rentToRepay,
            err: "// THEN: rented amount not expected"
        });
        assertEq({
            a: iToken0.balanceOf(bamm),
            b: uint256(token0InVault),
            err: "// THEN: Bamm balanceOf does not match tokens in vault"
        });
        assertEq({
            a: iToken1.balanceOf(bamm),
            b: uint256(token1InVault),
            err: "// THEN: bamm balanceOf does not match tokens in vault"
        });
    }

    function testFuzzRentNegativeAndTime(uint256 rentAmount, uint256 time) public {
        RentMath memory rentMath;

        //==============================================================================
        // Arrange
        //==============================================================================
        // GIVEN: user has open vault w/ sufficient liquidity & + rent
        time = bound(time, 1 days, 120 days);

        /// @notice Given `rentMultiplier`: 1e18 bamm token amount is equivalent to available rent
        uint256 maxRent = ((totalAvailableToRent * 9) / 10);
        rentAmount = bound(rentAmount, 1e5, (maxRent * 1) / 10);
        testFuzzRentPositive(rentAmount);
        uint256 rentToRepay = rentAmount / 2;
        (rentMath.token0, rentMath.token1, rentMath.rented) = iBamm.userVaults(tester2);

        vm.warp(block.timestamp + uint256(time));

        rentMath.lpBammBefore = iPair.balanceOf(bamm);

        //==============================================================================
        // Act
        //==============================================================================
        rentMath.lpOwed = _calculateLpFromRent(rentToRepay, true);
        (rentMath.token0amt, rentMath.token1amt) = _calculateTokensFromLp(rentMath.lpOwed, true);

        rentMath.expToken0Remaining = uint256(rentMath.token0) - rentMath.token0amt;
        rentMath.expToken1Remaining = uint256(rentMath.token1) - rentMath.token1amt;

        // WHEN: user repays a portion of their rent
        _bamm_rent({ _bamm: bamm, _user: tester2, _rent: -int256(rentToRepay) });

        //==============================================================================
        // Assert
        //==============================================================================
        rentMath.lpBammAfter = iPair.balanceOf(bamm);
        (int256 token0InVault, int256 token1InVault, int256 rentedInVault) = iBamm.userVaults(tester2);

        assertEq({
            a: rentMath.expToken0Remaining,
            b: uint256(token0InVault),
            err: "// THEN: token0 vault balance not expected"
        });
        assertEq({
            a: rentMath.expToken1Remaining,
            b: uint256(token1InVault),
            err: "// THEN: token1 vault balance not expected"
        });
        assertEq({
            a: rentMath.lpOwed,
            b: rentMath.lpBammAfter - rentMath.lpBammBefore,
            err: "// THEN: lp balance of bamm is not expected"
        });
        assertEq({
            a: uint256(rentedInVault),
            b: rentAmount - rentToRepay,
            err: "// THEN: rented amount not expected"
        });
        assertEq({
            a: iToken0.balanceOf(bamm),
            b: uint256(token0InVault),
            err: "// THEN: Bamm balanceOf does not match tokens in vault"
        });
        assertEq({
            a: iToken1.balanceOf(bamm),
            b: uint256(token1InVault),
            err: "// THEN: bamm balanceOf does not match tokens in vault"
        });
    }
}
