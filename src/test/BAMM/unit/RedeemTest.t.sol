// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import "../../helpers/BAMMTestHelper.sol";

contract RedeemTest is BAMMTestHelper {
    function setUp() public virtual {
        defaultSetup();
    }

    function test_Redeem_NoExistingFees_succeeds() public {
        //==============================================================================
        // Arrange
        //==============================================================================

        /// GIVEN: user has minted bamm
        uint256 balanceBefore = iPair.balanceOf(tester);
        uint256 amount = balanceBefore / 10;
        uint256 amountBamm = _calculateLPToBamm(amount) - iBamm.MINIMUM_LIQUIDITY();
        vm.startPrank(tester);
        iPair.approve(bamm, amount);
        iBamm.mint(tester, amount);

        //==============================================================================
        // Act
        //==============================================================================

        /// WHEN: user redeems partial amount of bamm
        uint256 redeemAmount = amountBamm / 4;
        uint256 lpToRedeem = _calculateBammToLP(redeemAmount);
        vm.startPrank(tester);
        iBamm.redeem(tester, redeemAmount);

        //==============================================================================
        // Assert
        //==============================================================================

        assertEq({
            a: iBammErc20.balanceOf(tester),
            b: amountBamm - redeemAmount,
            err: "/// THEN: incorrect amount redeemed"
        });
        assertEq({
            a: iPair.balanceOf(tester),
            b: balanceBefore - amount + lpToRedeem,
            err: "/// THEN: incorrect amount received"
        });
    }

    function test_Redeem_PreexistingFees_succeeds() public {
        //==============================================================================
        // Arrange
        //==============================================================================

        /// GIVEN: Alternative user has minted
        uint256 balanceBefore = iPair.balanceOf(tester);
        uint256 amount = balanceBefore / 10;
        vm.startPrank(tester);
        IERC20(pair).transfer(freshUser, amount);
        iPair.approve(bamm, amount);
        iBamm.mint(tester, amount);
        uint256 amountBammTester = _calculateLPToBamm(amount);
        vm.stopPrank();

        /// GIVEN: Renter exists in the market
        _bamm_deposit({
            _bamm: bamm,
            _token0: token0,
            _token1: token1,
            _user: tester2,
            _token0Amount: 1e19,
            _token1Amount: 0
        });
        _bamm_rent({ _bamm: bamm, _user: tester2, _rent: int256(1e18) });

        // GIVEN: Fees have accrued
        vm.warp(block.timestamp + 30 days);
        iBamm.addInterest();

        // GIVEN: The new user deposits, pre existing fees have accrued.
        uint256 amountBammFresh = _calculateLPToBamm(amount);

        vm.startPrank(freshUser);
        iPair.approve(bamm, amount);
        iBamm.mint(freshUser, amount);

        //==============================================================================
        // Act
        //==============================================================================

        /// WHEN: user redeems partial amount of bamm
        uint256 redeemAmount = amountBammFresh / 4;
        uint256 lpRedeemed = _calculateBammToLP(redeemAmount);
        vm.startPrank(freshUser);
        iBamm.redeem(freshUser, redeemAmount);

        //==============================================================================
        // Assert
        //==============================================================================
        assertEq({
            a: iBammErc20.balanceOf(freshUser),
            b: amountBammFresh - redeemAmount,
            err: "/// THEN: incorrect amount redeemed"
        });
        assertEq({ a: iPair.balanceOf(freshUser), b: lpRedeemed, err: "/// THEN: incorrect amount received" });
        assertLt({ a: amountBammFresh, b: amountBammTester, err: "/// THEN: pre existing fees not accounted for" });
    }

    function test_RedeemAll_DuringUserRent_reverts() public {
        //==============================================================================
        // Arrange
        //==============================================================================

        /// GIVEN: user has minted
        uint256 balanceBefore = iPair.balanceOf(tester);
        uint256 amount = balanceBefore / 10;
        vm.startPrank(tester);
        iPair.approve(bamm, amount);
        uint256 amountBamm = _calculateLPToBamm(amount) - iBamm.MINIMUM_LIQUIDITY();
        iBamm.mint(tester, amount);
        vm.stopPrank();

        /// GIVEN: Renter exists in the market
        _bamm_deposit({
            _bamm: bamm,
            _token0: token0,
            _token1: token1,
            _user: tester2,
            _token0Amount: 1e19,
            _token1Amount: 0
        });
        _bamm_rent({ _bamm: bamm, _user: tester2, _rent: int256(1e18) });
        uint256 rentedLp = _calculateBammToLP(1e18);

        // GIVEN: Fees have accrued
        vm.warp(block.timestamp + 30 days);
        iBamm.addInterest();

        //==============================================================================
        // Act
        //==============================================================================

        /// WHEN: user redeems total amount of bamm
        vm.startPrank(tester);
        vm.expectRevert(stdError.arithmeticError);
        iBamm.redeem(tester, amountBamm);

        //==============================================================================
        // Assert
        //==============================================================================

        assertEq({ a: iBammErc20.balanceOf(tester), b: amountBamm, err: "// THEN: tokens were redeemed" });
        assertEq({
            a: iPair.balanceOf(bamm),
            b: amount - rentedLp,
            err: "// THEN: bamm lp token balance not expected"
        });
    }

    function test_Redeem_TooMuch_reverts_singleUser() public {
        //==============================================================================
        // Arrange
        //==============================================================================

        /// GIVEN: user has minted
        uint256 balanceBefore = iPair.balanceOf(tester);
        uint256 amount = balanceBefore / 10;
        uint256 amountBamm = _calculateLPToBamm(amount) - iBamm.MINIMUM_LIQUIDITY();
        vm.startPrank(tester);
        iPair.approve(bamm, amount);
        iBamm.mint(tester, amount);
        vm.stopPrank();

        bytes memory reversion = abi.encodeWithSignature(
            "ERC20InsufficientBalance(address,uint256,uint256)",
            tester,
            amountBamm,
            amountBamm + 1
        );

        //==============================================================================
        // Act
        //==============================================================================

        // WHEN: user redeems too much bamm
        uint256 redeemAmount = amountBamm + 1;
        vm.expectRevert(reversion);
        vm.prank(tester);
        iBamm.redeem(tester, redeemAmount);
    }

    function test_Redeem_TooMuch_reverts_multipleUser() public {
        //==============================================================================
        // Arrange
        //==============================================================================

        /// GIVEN: user has minted
        uint256 balanceBefore = iPair.balanceOf(tester);
        uint256 amount = balanceBefore / 10;
        uint256 amountBamm = _calculateLPToBamm(amount) - iBamm.MINIMUM_LIQUIDITY();
        vm.startPrank(tester);
        iPair.approve(bamm, amount);
        iBamm.mint(tester, amount);
        vm.stopPrank();

        /// GIVEN: Alternative user has minted
        vm.startPrank(tester2);
        iPair.approve(bamm, 4e18);
        iBamm.mint(tester2, 4e18);
        vm.stopPrank();

        bytes memory reversion = abi.encodeWithSignature(
            "ERC20InsufficientBalance(address,uint256,uint256)",
            tester,
            amountBamm,
            amountBamm + 1
        );

        //==============================================================================
        // Act
        //==============================================================================

        // WHEN: user redeems too much bamm
        uint256 redeemAmount = amountBamm + 1;
        vm.expectRevert(reversion);
        vm.prank(tester);
        iBamm.redeem(tester, redeemAmount);
    }

    function test_Redeem_SomeoneElsesBamm_reverts() public {
        //==============================================================================
        // Arrange
        //==============================================================================

        /// GIVEN: Alternative user has minted
        uint256 balanceBefore = iPair.balanceOf(tester);
        uint256 amount = balanceBefore / 10;
        vm.startPrank(tester);
        iPair.approve(bamm, amount);
        iBamm.mint(tester, amount);
        uint256 amountBamm = _calculateLPToBamm(amount) - iBamm.MINIMUM_LIQUIDITY();
        vm.stopPrank();

        bytes memory reversion = abi.encodeWithSignature(
            "ERC20InsufficientBalance(address,uint256,uint256)",
            freshUser,
            0,
            amountBamm
        );

        //==============================================================================
        // Act
        //==============================================================================

        /// WHEN: user redeems total amount of bamm
        vm.expectRevert(reversion);
        vm.prank(freshUser);
        iBamm.redeem(freshUser, amountBamm);
    }
}
