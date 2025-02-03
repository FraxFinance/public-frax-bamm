// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import "../../helpers/BAMMTestHelper.sol";

contract RentTest is BAMMTestHelper {
    function setUp() public virtual {
        defaultSetup();
    }

    function test_Rent_PreExistingFeesRenter_suceeds() public {
        //==============================================================================
        // Arrange
        //==============================================================================

        /// GIVEN: tester has minted bamm
        uint256 amount = iPair.balanceOf(tester) / 10;
        vm.startPrank(tester);
        iPair.approve(bamm, amount);
        iBamm.mint(tester, amount);
        vm.stopPrank();

        /// GIVEN: tester2 deposits token0 as collateral
        _bamm_deposit({
            _bamm: bamm,
            _token0: token0,
            _token1: token1,
            _user: tester2,
            _token0Amount: 1e19,
            _token1Amount: 0
        });
        uint256 lpInitial = iPair.balanceOf(bamm);

        //==============================================================================
        // Act
        //==============================================================================

        /// WHEN: tester2 rents 1 unit
        _bamm_rent({ _bamm: bamm, _user: tester2, _rent: int256(1e18) });

        //==============================================================================
        // Assert
        //==============================================================================

        // passes
        uint256 lpExpected = _calculateLpFromRent(1e18, false);
        (uint256 token0Owed, uint256 token1Owed) = _calculateTokensFromLp(lpExpected, false);
        (, , int256 rented) = iBamm.userVaults(tester2);
        assertEq({
            a: lpInitial - lpExpected,
            b: iPair.balanceOf(bamm),
            err: "// THEN: lp balance of bamm not expected"
        });
        assertEq({
            a: 10e18 + token0Owed,
            b: iToken0.balanceOf(bamm),
            err: "// THEN: token0 amount bamm not expected"
        });
        assertEq({ a: token1Owed, b: iToken1.balanceOf(bamm), err: "// THEN: token1 amount bamm not expected" });
        assertEq({ a: rented, b: 1e18, err: "// THEN: rented amount not expected" });
    }

    function test_Rent_NoFeesRenter_succeeds() public {
        //==============================================================================
        // Arrange
        //==============================================================================
        /// GIVEN: we have a newly created pair
        _createFreshBamm();

        /// GIVEN: tester has minted bamm
        uint256 amount = iPair.balanceOf(tester);
        vm.startPrank(tester);
        iPair.approve(bamm, amount);
        iBamm.mint(tester, amount);
        vm.stopPrank();

        /// GIVEN: tester2 deposits token0 as collateral
        _bamm_deposit({
            _bamm: bamm,
            _token0: token0,
            _token1: token1,
            _user: tester2,
            _token0Amount: 1e19,
            _token1Amount: 0
        });
        uint256 lpInitial = iPair.balanceOf(bamm);

        //==============================================================================
        // Act
        //==============================================================================

        /// WHEN: tester2 rents 1 unit
        _bamm_rent({ _bamm: bamm, _user: tester2, _rent: int256(0.75e18) });

        //==============================================================================
        // Assert
        //==============================================================================

        // passes
        uint256 lpExpected = _calculateLpFromRent(0.75e18, false);
        (uint256 token0Owed, uint256 token1Owed) = _calculateTokensFromLp(lpExpected, false);
        (, , int256 rented) = iBamm.userVaults(tester2);
        assertEq({
            a: lpInitial - lpExpected,
            b: iPair.balanceOf(bamm),
            err: "// THEN: lp balance of bamm not expected"
        });
        assertEq({
            a: 10e18 + token0Owed,
            b: iToken0.balanceOf(bamm),
            err: "// THEN: token0 amount bamm not expected"
        });
        assertEq({ a: token1Owed, b: iToken1.balanceOf(bamm), err: "// THEN: token1 amount bamm not expected" });
        assertEq({ a: rented, b: 0.75e18, err: "// THEN: rented amount not expected" });
    }

    function _setupLpFees() public {
        address borrower = address(0xBEEF);

        /// GIVEN: we have a newly created pair with lp available to rune
        _createFreshBamm();

        // set fees on
        turnDexFeeOn(iPair);

        uint256 testerPairBalanceBefore = iPair.balanceOf(tester);
        uint256 lpMinted = testerPairBalanceBefore / 2;

        _bamm_mint({ _bamm: bamm, _user: tester, _to: tester, _pair: pair, _amountPair: lpMinted });
        /// @notice `_calculateLPToBamm` can be called after mint given `sqrtRentedReal` = 0
        uint256 totalAvailableToRent = _calculateLPToBamm(lpMinted);

        assertEq(iBamm.rentedMultiplier(), 1e18);
        uint256 rentAmount = (totalAvailableToRent * 50) / 100;
        _bamm_deposit({
            _bamm: bamm,
            _token0: token0,
            _token1: token1,
            _user: borrower,
            _token0Amount: 300e18,
            _token1Amount: 300e18
        });
        _bamm_rent({ _bamm: bamm, _user: borrower, _rent: int256(rentAmount) });

        mineBlocksBySecond(7 days);
        iBamm.addInterest();
        mineBlocksBySecond(7 days);

        assertGt({ a: iPair.kLast(), b: 0, err: "// THEN: KLast not initialized" });

        ERC20Mock(token0).mint(address(iPair), 5000e18);
        ERC20Mock(token1).mint(address(iPair), 5000e18);

        iPair.sync();

        _bamm_deposit({
            _bamm: bamm,
            _token0: token0,
            _token1: token1,
            _user: tester,
            _token0Amount: 300e18,
            _token1Amount: 300e18
        });

        uint256 lpBalanceSwapPairFeeRecipient = iPair.balanceOf(address(0xFEE2));
        assertEq({ a: lpBalanceSwapPairFeeRecipient, b: 0, err: "// THEN: iPair fee recipient already minted" });
    }

    function test_rent_anticipates_swapPairFees() public {
        //==============================================================================
        // Arrange
        //==============================================================================
        _setupLpFees();

        uint256 token0Before = iToken0.balanceOf(bamm);
        uint256 token1Before = iToken1.balanceOf(bamm);
        //==============================================================================
        // Act
        //==============================================================================

        IBAMM.Action memory action;
        action.rent = 100e18;
        vm.startPrank(tester);
        iBamm.executeActions(action);
        vm.stopPrank();

        //==============================================================================
        // Assert
        //==============================================================================

        (int256 token0Vault, int256 token1Vault, ) = iBamm.userVaults(tester);
        assertEq({
            a: uint256(token0Vault) - 300e18,
            b: iToken0.balanceOf(bamm) - token0Before,
            err: "// THEN: More Tokens in vault than unwrapped"
        });
        assertEq({
            a: uint256(token1Vault) - 300e18,
            b: iToken1.balanceOf(bamm) - token1Before,
            err: "// THEN: More Tokens in vault than unwrapped"
        });
        assertGt({ a: iPair.balanceOf(address(0xFEE2)), b: 0, err: "// THEN: iPair fee recipient was not minted" });
    }

    function test_calcRent_returns_correctAmt_token1() public {
        /// GIVEN: tester has minted bamm
        uint256 amount = iPair.balanceOf(tester);
        vm.startPrank(tester);
        iPair.approve(bamm, amount);
        iBamm.mint(tester, amount);
        vm.stopPrank();

        /// GIVEN: tester2 deposits token0 as collateral
        _bamm_deposit({
            _bamm: bamm,
            _token0: token0,
            _token1: token1,
            _user: tester2,
            _token0Amount: 1000e18,
            _token1Amount: 0
        });
        uint256 lpInitial = iPair.balanceOf(bamm);

        (int256 toRent, uint256 lpUnwound, uint256 amountOutOtherToken) = iBammUIHelper.calcRent(
            iBamm,
            address(iToken1),
            1e18
        );

        IBAMM.Action memory action;
        action.rent = toRent;

        vm.prank(tester2);
        iBamm.executeActions(action);

        BAMM.Vault memory vault;
        (vault.token0, vault.token1, vault.rented) = iBamm.userVaults(tester2);
        uint256 token0Diff = iToken0.balanceOf(bamm) - (1000e18 + amountOutOtherToken);
        uint256 token1Diff = iToken1.balanceOf(bamm) - 1e18;

        assertEq({
            a: lpInitial - iPair.balanceOf(bamm),
            b: lpUnwound,
            err: "// THEN: projected lp unwound does not match state"
        });
        assertLt({ a: token0Diff, b: 50, err: "// THEN: projected token0 does not match state" });
        assertLt({ a: token1Diff, b: 50, err: "// THEN: projected token1 does not match state" });
        assertEq({
            a: iToken0.balanceOf(bamm),
            b: uint256(vault.token0),
            err: "// THEN: state does not match vault accounting"
        });
        assertEq({
            a: iToken1.balanceOf(bamm),
            b: uint256(vault.token1),
            err: "// THEN: state does not match vault accounting"
        });
        assertEq({ a: vault.rented, b: toRent, err: "// THEN: vault does not match input" });
    }

    function test_calcRent_returns_correctAmt_token0() public {
        /// GIVEN: tester has minted bamm
        uint256 amount = iPair.balanceOf(tester);
        vm.startPrank(tester);
        iPair.approve(bamm, amount);
        iBamm.mint(tester, amount);
        vm.stopPrank();

        /// GIVEN: tester2 deposits token0 as collateral
        _bamm_deposit({
            _bamm: bamm,
            _token0: token0,
            _token1: token1,
            _user: tester2,
            _token0Amount: 0,
            _token1Amount: 1e18
        });
        uint256 lpInitial = iPair.balanceOf(bamm);

        (int256 toRent, uint256 lpUnwound, uint256 amountOutOtherToken) = iBammUIHelper.calcRent(
            iBamm,
            address(iToken0),
            uint256(1e18)
        );

        IBAMM.Action memory action;
        action.rent = toRent;

        vm.prank(tester2);
        iBamm.executeActions(action);

        BAMM.Vault memory vault;
        (vault.token0, vault.token1, vault.rented) = iBamm.userVaults(tester2);
        uint256 token0Diff = iToken0.balanceOf(bamm) - 1e18;
        uint256 token1Diff = iToken1.balanceOf(bamm) - (1e18 + amountOutOtherToken);

        assertEq({
            a: lpInitial - iPair.balanceOf(bamm),
            b: lpUnwound,
            err: "// THEN: projected lp unwound does not match state"
        });
        console.log(address(iToken0));
        assertLt({ a: token0Diff, b: 5000, err: "// THEN: projected token0 does not match state" });
        assertLt({ a: token1Diff, b: 5000, err: "// THEN: projected token1 does not match state" });
        assertEq({
            a: iToken0.balanceOf(bamm),
            b: uint256(vault.token0),
            err: "// THEN: state does not match vault accounting"
        });
        assertEq({
            a: iToken1.balanceOf(bamm),
            b: uint256(vault.token1),
            err: "// THEN: state does not match vault accounting"
        });
        assertEq({ a: vault.rented, b: toRent, err: "// THEN: vault does not match input" });
    }

    function test_calcRent_returns_correctAmt_token0_withFees() public {
        _setupLpFees();

        uint256 amount = iPair.balanceOf(tester);
        vm.startPrank(tester);
        iPair.approve(bamm, amount);
        iBamm.mint(tester, amount);
        vm.stopPrank();

        /// GIVEN: tester2 deposits token0 as collateral
        _bamm_deposit({
            _bamm: bamm,
            _token0: token0,
            _token1: token1,
            _user: tester2,
            _token0Amount: 0,
            _token1Amount: 1e18
        });
        uint256 lpInitial = iPair.balanceOf(bamm);

        (int256 toRent, uint256 lpUnwound, ) = iBammUIHelper.calcRent(iBamm, address(iToken0), 1e18);

        IBAMM.Action memory action;
        action.rent = toRent;

        vm.prank(tester2);
        iBamm.executeActions(action);

        BAMM.Vault memory vault;
        (vault.token0, vault.token1, vault.rented) = iBamm.userVaults(tester2);

        assertEq({
            a: lpInitial - iPair.balanceOf(bamm),
            b: lpUnwound,
            err: "// THEN: projected lp unwound does not match state"
        });
        assertGt({ a: uint256(vault.token0), b: 1e18, err: "// THEN: state does not match vault accounting" });
        assertEq({ a: vault.rented, b: toRent, err: "// THEN: vault does not match input" });
    }

    function test_calcRent_returns_correctAmt_token1_withFees() public {
        _setupLpFees();

        /// GIVEN: tester has minted bamm
        uint256 amount = iPair.balanceOf(tester);
        vm.startPrank(tester);
        iPair.approve(bamm, amount);
        iBamm.mint(tester, amount);
        vm.stopPrank();

        /// GIVEN: tester2 deposits token0 as collateral
        _bamm_deposit({
            _bamm: bamm,
            _token0: token0,
            _token1: token1,
            _user: tester2,
            _token0Amount: 1000e18,
            _token1Amount: 0
        });
        uint256 lpInitial = iPair.balanceOf(bamm);
        // iBamm.addInterest();
        (int256 toRent, uint256 lpUnwound, ) = iBammUIHelper.calcRent(iBamm, address(iToken1), 1e18);

        IBAMM.Action memory action;
        action.rent = toRent;

        iBamm.addInterest();
        vm.prank(tester2);
        iBamm.executeActions(action);

        BAMM.Vault memory vault;
        (vault.token0, vault.token1, vault.rented) = iBamm.userVaults(tester2);

        assertEq({
            a: lpInitial - iPair.balanceOf(bamm),
            b: lpUnwound,
            err: "// THEN: projected lp unwound does not match state"
        });
        assertGt({ a: uint256(vault.token1), b: 1e18, err: "// THEN: state does not match vault accounting" });
        assertEq({ a: vault.rented, b: toRent, err: "// THEN: vault does not match input" });
    }

    function test_rentWithNoBammERC20Mint_reverts() public {
        _createFreshBamm();

        // Donate to Bamm
        vm.startPrank(tester);
        iPair.transfer(address(iBamm), iPair.balanceOf(tester));
        vm.stopPrank();

        vm.startPrank(tester);
        iToken0.approve(address(iBamm), 1e18);

        BAMM.Action memory action;
        action.token0Amount = 1e18;
        action.rent = 0.25e18;

        vm.expectRevert(IBAMM.NoBAMMTokensMinted.selector);
        iBamm.executeActions(action);
    }
}
