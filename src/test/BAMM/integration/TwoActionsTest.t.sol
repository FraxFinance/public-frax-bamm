// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import "../../BaseTest.t.sol";
import "../../helpers/BAMMTestHelper.sol";

contract TwoActionsTest is BAMMTestHelper {
    /// @dev these tests are for multiple actions executed atomicly through `executeActionsAndSwap()`
    function setUp() public {
        defaultSetup();

        // Deposit to pair
        uint256 amount = iPair.balanceOf(tester);
        vm.startPrank(tester);
        iPair.approve(bamm, amount);
        iBamm.mint(tester, amount);
        vm.stopPrank();
    }

    function test_TwoActions_DepositBorrow_succeeds() public {
        uint256 bammLpStart = iPair.balanceOf(bamm);

        // deal alice some token1
        _dealAndApproveBamm(alice, 0, 100e18);

        IBAMM.Action memory action;
        action.token0Amount = -100e18;
        action.token1Amount = 100e18;
        action.rent = 100e18;

        uint256 expLpRented = _calculateLpFromRent(100e18, false);
        (uint256 expToken0Unwraped, uint256 expToken1Unwapped) = _calculateTokensFromLp(expLpRented, false);

        vm.prank(alice);
        iBamm.executeActions(action);

        BAMM.Vault memory vault;
        (vault.token0, vault.token1, vault.rented) = iBamm.userVaults(alice);

        assertEq({
            a: int256(iToken0.balanceOf(bamm)),
            b: int256(expToken0Unwraped) + action.token0Amount,
            err: "// THEN: token0 balance of bamm not expected"
        });
        assertEq({
            a: int256(iToken1.balanceOf(bamm)),
            b: int256(expToken1Unwapped) + action.token1Amount,
            err: "// THEN: token1 balance of bamm not expected"
        });
        assertEq({
            a: bammLpStart - iPair.balanceOf(bamm),
            b: expLpRented,
            err: "// THEN: lp balance of bamm not expected"
        });
        assertEq({
            a: uint256(vault.token0),
            b: iToken0.balanceOf(bamm),
            err: "// THEN: vault token0 balance does not match state"
        });
        assertEq({
            a: uint256(vault.token1),
            b: iToken1.balanceOf(bamm),
            err: "// THEN: vault token1 balance does not match state"
        });
        assertEq({ a: vault.rented, b: action.rent, err: "// THEN: vault rented does not match input" });
        assertEq({
            a: int256(expToken0Unwraped) - vault.token0,
            b: int256(iToken0.balanceOf(alice)),
            err: "// THEN: vault balance does not reflect alice's borrow"
        });
        assertEq({ a: iBamm.sqrtRented(), b: vault.rented, err: "// THEN: vault rented not consistent w/ sqrtRented" });
    }

    function test_TwoActions_DepositSwap_succeeds() public {
        _dealAndApproveBamm(alice, 0, 100e18);

        // swap 1/4 of the lp unwrapped
        IFraxswapRouterMultihop.FraxswapParams memory swapParams;
        uint256 expToken0 = iPair.getAmountOut(1e18, address(iToken1));
        swapParams = _createSwapParams(address(iToken1), 1e18, address(iToken0), bamm);

        IBAMM.Action memory action;
        action.token1Amount = 100e18;

        vm.prank(alice);
        iBamm.executeActionsAndSwap(action, swapParams);

        BAMM.Vault memory vault;
        (vault.token0, vault.token1, vault.rented) = iBamm.userVaults(alice);

        assertEq({
            a: iToken0.balanceOf(bamm),
            b: uint256(vault.token0),
            err: "// THEN: vault balance of token0 does not match state"
        });
        assertEq({
            a: iToken1.balanceOf(bamm),
            b: uint256(vault.token1),
            err: "// THEN: vault balance of token1 does not match state"
        });
        assertEq({
            a: vault.token1,
            b: action.token1Amount - int256(swapParams.amountIn),
            err: "// THEN: vault does is not sum of deposit and swap"
        });
        assertEq({ a: uint256(vault.token0), b: expToken0, err: "// THEN: vault does not reflect output of swap" });
    }

    function test_TwoActions_DepositRepay_succeeds() public {
        _dealAndApproveBamm(alice, 20e18, 20e18);

        IBAMM.Action memory action;
        BAMM.Vault memory vault;

        action.token0Amount = 10e18;
        action.token1Amount = 10e18;
        action.rent = 10e18;

        vm.prank(alice);
        iBamm.executeActions(action);

        action.rent = -action.rent;
        vm.prank(alice);
        iBamm.executeActions(action);

        (vault.token0, vault.token1, vault.rented) = iBamm.userVaults(alice);

        // Assert that vault is actually closed out and tokens are returned to alice
        assertEq({ a: vault.token0, b: 20e18 - 46, err: "// THEN: vault token0 not closed" });
        assertEq({ a: vault.token1, b: 20e18 - 1, err: "// THEN: vault token1 not closed" });
        assertEq({ a: vault.rented, b: 0, err: "// THEN: vault rent not closed" });
    }

    function test_TwoActions_DepositClosePosition_succeeds() public {
        _dealAndApproveBamm(alice, 10e18, 10e18);

        IBAMM.Action memory action;
        BAMM.Vault memory vault;

        action.token0Amount = 10e18;
        action.token1Amount = 10e18;
        action.closePosition = true;

        vm.prank(alice);
        iBamm.executeActions(action);

        (vault.token0, vault.token1, vault.rented) = iBamm.userVaults(alice);

        // Assert that vault is actually closed out and tokens are returned to alice
        assertEq({ a: vault.token0, b: 0, err: "// THEN: vault token0 not closed" });
        assertEq({ a: vault.token1, b: 0, err: "// THEN: vault token1 not closed" });
        assertEq({ a: vault.rented, b: 0, err: "// THEN: vault rent not closed" });
        assertEq({ a: iToken0.balanceOf(alice), b: 10e18, err: "// THEN: token0 not returned to alice" });
        assertEq({ a: iToken1.balanceOf(alice), b: 10e18, err: "// THEN: token1 not returned to alice" });
    }

    function test_TwoActions_SwapClosePosition_succeeds() public {
        _dealAndApproveBamm(alice, 0, 100e18);

        IBAMM.Action memory action;
        action.token1Amount = 100e18;
        action.rent = 100e18;

        vm.prank(alice);
        iBamm.executeActions(action);

        // Buy 1M eth at market
        marketBuy(20_000e18);

        action.token0Amount = 0;
        action.token1Amount = 0;
        action.rent = 0;
        action.closePosition = true;

        vm.prank(alice);
        vm.expectRevert();
        iBamm.executeActions(action);

        uint256 lpBammBefore = iPair.balanceOf(bamm);

        BAMM.Vault memory vaultBefore;
        (vaultBefore.token0, vaultBefore.token1, vaultBefore.rented) = iBamm.userVaults(alice);

        uint256 expToken0 = iPair.getAmountOut(1e18, address(iToken1));

        // Modify helper function state to account for swap
        int256 resAToChange = -int256(expToken0);
        int256 resBToChange = 1e18;

        uint256 expLpOwed = _calculateLpFromRentWithReserveDelta(100e18, resAToChange, resBToChange, true);
        (uint256 expToken0ToRepay, uint256 expToken1ToRepay) = _calculateTokensFromLpWithReserveDelta(
            expLpOwed,
            resAToChange,
            resBToChange,
            true
        );

        IFraxswapRouterMultihop.FraxswapParams memory swapParams;
        swapParams = _createSwapParams(address(iToken1), 1e18, address(iToken0), bamm);

        vm.prank(alice);
        iBamm.executeActionsAndSwap(action, swapParams);

        BAMM.Vault memory vaultAfter;
        (vaultAfter.token0, vaultAfter.token1, vaultAfter.rented) = iBamm.userVaults(alice);

        assertEq({
            a: iToken0.balanceOf(alice),
            b: uint256(vaultBefore.token0) + expToken0 - expToken0ToRepay,
            err: "// THEN: token0 balance of alice after repay and swap not expected"
        });
        assertEq({
            a: iToken1.balanceOf(alice),
            b: uint256(vaultBefore.token1) - (expToken1ToRepay + 1e18),
            err: "// THEN: token1 balance of alice after repay and swap not expected"
        });
        assertEq({
            a: iPair.balanceOf(bamm) - lpBammBefore,
            b: expLpOwed,
            err: "// THEN: the lp given to the bamm after "
        });
        assertEq({ a: vaultAfter.token0, b: 0, err: "// THEN: vault token0 not closed" });
        assertEq({ a: vaultAfter.token1, b: 0, err: "// THEN: vault token1 not closed" });
        assertEq({ a: vaultAfter.rented, b: 0, err: "// THEN: vault rent not closed" });
    }

    function test_TwoActions_BorrowWithdraw_succeeds() public {
        _dealAndApproveBamm(alice, 0, 100e18);

        IBAMM.Action memory action;
        action.token1Amount = 100e18;

        vm.prank(alice);
        iBamm.executeActions(action);

        BAMM.Vault memory vaultBefore;
        (vaultBefore.token0, vaultBefore.token1, vaultBefore.rented) = iBamm.userVaults(alice);

        uint256 expLpUnwound = _calculateLpFromRent(100e18, false);
        (uint256 expToken0ToUnwind, uint256 expToken1ToUnwind) = _calculateTokensFromLp(expLpUnwound, false);

        action.token0Amount = -1e18;
        action.token1Amount = 0;
        action.rent = 100e18;

        uint256 lpBammBefore = iPair.balanceOf(bamm);

        vm.prank(alice);
        iBamm.executeActions(action);

        BAMM.Vault memory vaultAfter;
        (vaultAfter.token0, vaultAfter.token1, vaultAfter.rented) = iBamm.userVaults(alice);

        assertEq({
            a: vaultBefore.token0 + int256(expToken0ToUnwind),
            b: vaultAfter.token0 + int256(iToken0.balanceOf(alice)),
            err: "// THEN: vault token0 balance not incremented correctly"
        });
        assertEq({
            a: vaultBefore.token1 + int256(expToken1ToUnwind),
            b: vaultAfter.token1 + int256(iToken1.balanceOf(alice)),
            err: "// THEN: vault token0 balance not incremented correctly"
        });
        assertEq({
            a: lpBammBefore - iPair.balanceOf(bamm),
            b: expLpUnwound,
            err: "// THEN: lp rented does not match state"
        });
        assertEq({
            a: iBamm.sqrtRented(),
            b: vaultAfter.rented,
            err: "// THEN: vault rented not consistent w/ sqrtRented"
        });
    }

    function test_TwoActions_SwapWithdraw_succeeds() public {
        _dealAndApproveBamm(alice, 100e18, 0);

        IBAMM.Action memory action;
        action.token0Amount = 100e18;

        vm.prank(alice);
        iBamm.executeActions(action);

        uint256 expToken0 = iPair.getAmountOut(100e18, address(iToken0));

        action.token1Amount -= int256(expToken0);
        action.token0Amount = 0;

        IFraxswapRouterMultihop.FraxswapParams memory swapParams;
        swapParams = _createSwapParams(address(iToken0), 100e18, address(iToken1), alice);
        vm.prank(alice);
        iBamm.executeActionsAndSwap(action, swapParams);
        BAMM.Vault memory vaultAfter;
        (vaultAfter.token0, vaultAfter.token1, vaultAfter.rented) = iBamm.userVaults(alice);

        assertEq({ a: iToken0.balanceOf(alice), b: 0, err: "// THEN: token0 balance withdrawn does not match state" });
        assertEq({
            a: iToken1.balanceOf(alice),
            b: uint256(-action.token1Amount),
            err: "// THEN: token0 balance withdrawn does not match state"
        });
        assertEq({ a: vaultAfter.token0, b: 0, err: "// THEN: vault token0 not closed" });
        assertEq({ a: vaultAfter.token1, b: 0, err: "// THEN: vault token1 not closed" });
        assertEq({ a: vaultAfter.rented, b: 0, err: "// THEN: vault rent not closed" });
    }
}
