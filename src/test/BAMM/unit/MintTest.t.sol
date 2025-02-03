// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import "../../helpers/BAMMTestHelper.sol";

contract MintTest is BAMMTestHelper {
    function setUp() public virtual {
        defaultSetup();
    }

    function test_Mint_PreExistingFeesInitialMint_succeeds() public {
        /// @dev mints initial liquidity
        //==============================================================================
        // Arrange
        //==============================================================================

        /// GIVEN: user wants to mint and contains enough LP tokens
        uint256 balanceBefore = iPair.balanceOf(tester);
        uint256 amount = balanceBefore / 10;

        //==============================================================================
        // Act
        //==============================================================================

        /// WHEN: user mints BAMMErc20
        uint256 bammOut = _calculateLPToBamm(amount);
        _bamm_mint({ _bamm: bamm, _user: tester, _to: tester, _pair: pair, _amountPair: amount });

        //==============================================================================
        // Assert
        //==============================================================================

        assertEq({
            a: iBammErc20.balanceOf(address(1)),
            b: iBamm.MINIMUM_LIQUIDITY(),
            err: "address(1) should have permanent minimum liquidity"
        });
        assertEq({
            a: iBammErc20.balanceOf(tester),
            b: bammOut - iBamm.MINIMUM_LIQUIDITY(),
            err: "/// THEN: incorrect amount minted"
        });
        assertEq({
            a: iPair.balanceOf(tester),
            b: balanceBefore - amount,
            err: "/// THEN: incorrect amount deposited"
        });
        assertEq({ a: iBammErc20.totalSupply(), b: bammOut, err: "incorrect total supply" });
    }

    function test_Mint_PreExistingFeesSecondMintNoRent_succeeds() public {
        //==============================================================================
        // Arrange
        //==============================================================================

        /// GIVEN: someone has already minted BAMMErc20
        uint256 balanceBeforeUser = iPair.balanceOf(tester);
        uint256 amount = balanceBeforeUser / 10;
        _bamm_mint({ _bamm: bamm, _user: tester, _to: tester, _pair: pair, _amountPair: amount });

        uint256 bammSupplyBefore = iBammErc20.totalSupply();
        uint256 pairSupplyBefore = iPair.totalSupply();

        /// GIVEN: user wants to mint and contains enough LP tokens
        uint256 balanceBeforeBamm = iPair.balanceOf(bamm);
        balanceBeforeUser = iPair.balanceOf(tester2);
        amount = balanceBeforeUser / 10;

        /// @dev calculations to execute when iBammErc20.totalSupply() > 0 with no rented liquidity
        uint256 bammOut = _calculateLPToBamm(amount);

        //==============================================================================
        // Act
        //==============================================================================

        /// WHEN: user mints BAMMErc20
        _bamm_mint({ _bamm: bamm, _user: tester2, _to: tester2, _pair: pair, _amountPair: amount });

        //==============================================================================
        // Assert
        //==============================================================================

        assertEq({ a: iBammErc20.totalSupply() - bammSupplyBefore, b: bammOut, err: "incorrect amount bamm minted" });
        assertEq({ a: iBammErc20.balanceOf(tester2), b: bammOut, err: "incorrect amount bamm received" });
        assertEq({
            a: balanceBeforeUser - iPair.balanceOf(tester2),
            b: amount,
            err: "incorrect amount pair deposited"
        });
        assertEq({ a: iPair.totalSupply(), b: pairSupplyBefore, err: "pair supply should not change" });
        assertEq({ a: iPair.balanceOf(bamm) - balanceBeforeBamm, b: amount, err: "incorrect amount pair received" });
    }

    function test_Mint_PreExistingFeesSecondMintPreExistingRent_succeeds() public {
        //==============================================================================
        // Arrange
        //==============================================================================

        /// GIVEN: someone has already minted BAMMErc20
        uint256 balanceBeforeUser = iPair.balanceOf(tester);
        uint256 amount = balanceBeforeUser / 10;
        _bamm_mint({ _bamm: bamm, _user: tester, _to: tester, _pair: pair, _amountPair: amount });

        // GIVEN: someone has already rented

        uint256 bammSupplyBefore = iBammErc20.totalSupply();
        uint256 pairSupplyBefore = iPair.totalSupply();

        /// GIVEN: user wants to mint and contains enough LP tokens
        uint256 balanceBeforeBamm = iPair.balanceOf(bamm);
        balanceBeforeUser = iPair.balanceOf(tester2);
        amount = balanceBeforeUser / 10;

        /// @dev calculations to execute when iBammErc20.totalSupply() > 0 with no rented liquidity
        uint256 bammOut = _calculateLPToBamm(amount);

        //==============================================================================
        // Act
        //==============================================================================

        /// WHEN: user mints BAMMErc20
        vm.startPrank(tester2);
        iPair.approve(bamm, amount);
        iBamm.mint(tester2, amount);

        //==============================================================================
        // Assert
        //==============================================================================

        assertEq({ a: iBammErc20.totalSupply() - bammSupplyBefore, b: bammOut, err: "incorrect amount bamm minted" });
        assertEq({ a: iBammErc20.balanceOf(tester2), b: bammOut, err: "incorrect amount bamm received" });
        assertEq({
            a: balanceBeforeUser - iPair.balanceOf(tester2),
            b: amount,
            err: "incorrect amount pair deposited"
        });
        assertEq({ a: iPair.totalSupply(), b: pairSupplyBefore, err: "pair supply should not change" });
        assertEq({ a: iPair.balanceOf(bamm) - balanceBeforeBamm, b: amount, err: "incorrect amount pair received" });
    }

    function test_Mint_NoExistingFees_succeeds() public {
        _createFreshBamm();
        test_Mint_PreExistingFeesInitialMint_succeeds();
    }

    function test_Mint_AfterInterestShouldReceiveLessBAMM_succeeds() public {
        _bamm_mint({ _bamm: bamm, _user: tester, _to: tester, _pair: pair, _amountPair: 10e18 });

        _bamm_deposit({
            _bamm: bamm,
            _token0: token0,
            _token1: token1,
            _user: freshUser,
            _token0Amount: 100e18,
            _token1Amount: 100e18
        });

        _bamm_rent({ _bamm: bamm, _user: freshUser, _rent: int256(9e18) });

        vm.warp(block.timestamp + 10 days);
        iBamm.addInterest();

        vm.warp(block.timestamp + 10 days);
        iBamm.addInterest();

        _bamm_mint({ _bamm: bamm, _user: tester2, _to: tester2, _pair: pair, _amountPair: 10e18 });

        assertGt({
            a: iBammErc20.balanceOf(tester),
            b: iBammErc20.balanceOf(tester2),
            err: "// THEN: Bamm awarded after interest accrual is not less"
        });
    }

    function test_tooSmall_mint_reverts() public {
        test_Mint_AfterInterestShouldReceiveLessBAMM_succeeds();

        // Inflate the rent multiplier
        vm.store(address(iBamm), bytes32(uint256(3)), bytes32(uint256(10_000e18)));

        vm.startPrank(tester);
        IERC20(address(iPair)).approve(address(iBamm), 1);
        vm.expectRevert(IBAMM.ZeroLiquidityMinted.selector);
        iBamm.mint(tester, 1);
    }
}
