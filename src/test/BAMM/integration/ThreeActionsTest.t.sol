// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import "../../BaseTest.t.sol";
import "../../helpers/BAMMTestHelper.sol";

contract ThreeActionsTest is BAMMTestHelper {
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

    function test_ThreeActions_DepositBorrowSwap_succeeds() public {
        uint256 bammLpStart = iPair.balanceOf(bamm);

        // deal alice some token0
        _dealAndApproveBamm(alice, 5000e18, 0);

        IBAMM.Action memory action;
        action.token0Amount = 5000e18;
        action.rent = 100e18;

        uint256 expLpOwed = _calculateLpFromRent(100e18, false);
        (uint256 expToken0Owed, uint256 expToken1Owed) = _calculateTokensFromLp(expLpOwed, false);

        uint256 expToken0Swap = _amountOutPostLpUnwind(expLpOwed, 1e18, address(iToken1));
        IFraxswapRouterMultihop.FraxswapParams memory swapParams;
        swapParams = _createSwapParams(address(iToken1), 1e18, address(iToken0), bamm);

        vm.prank(alice);
        iBamm.executeActionsAndSwap(action, swapParams);

        BAMM.Vault memory vault;
        (vault.token0, vault.token1, vault.rented) = iBamm.userVaults(alice);

        assertEq({
            a: expLpOwed,
            b: bammLpStart - iPair.balanceOf(bamm),
            err: "// THEN: expected lp to be unwrapped does not match state"
        });
        assertEq({
            a: iToken0.balanceOf(bamm),
            b: expToken0Owed + uint256(action.token0Amount) + expToken0Swap,
            err: "// THEN: expected token0 balance bamm does not match state"
        });
        assertEq({
            a: iToken1.balanceOf(bamm),
            b: expToken1Owed + uint256(action.token1Amount) - 1e18,
            err: "// THEN: expected token1 balance bamm does not match state"
        });
        assertEq({ a: vault.rented, b: action.rent, err: "// THEN: vault rented does not match input" });
        assertEq({
            a: uint256(vault.token0),
            b: iToken0.balanceOf(bamm),
            err: "// THEN: vault accounting token0 does not match state"
        });
        assertEq({
            a: uint256(vault.token1),
            b: iToken1.balanceOf(bamm),
            err: "// THEN: vault accounting token1 does not match state"
        });
        assertEq({ a: iBamm.sqrtRented(), b: vault.rented, err: "// THEN: vault rented not consistent w/ sqrtRented" });
    }

    function test_ThreeActions_DepositBorrowSwapWithdraw_succeeds() public {
        uint256 bammLpStart = iPair.balanceOf(bamm);

        // deal alice some token0
        _dealAndApproveBamm(alice, 5000e18, 0);

        IBAMM.Action memory action;
        action.token0Amount = 5000e18;
        action.token1Amount = -0.05e18;
        action.rent = 100e18;

        uint256 expLpOwed = _calculateLpFromRent(100e18, false);
        (uint256 expToken0Owed, uint256 expToken1Owed) = _calculateTokensFromLp(expLpOwed, false);

        uint256 expToken0Swap = _amountOutPostLpUnwind(expLpOwed, 1e18, address(iToken1));
        IFraxswapRouterMultihop.FraxswapParams memory swapParams;
        swapParams = _createSwapParams(address(iToken1), 1e18, address(iToken0), bamm);

        vm.prank(alice);
        iBamm.executeActionsAndSwap(action, swapParams);

        BAMM.Vault memory vault;
        (vault.token0, vault.token1, vault.rented) = iBamm.userVaults(alice);

        assertEq({
            a: expLpOwed,
            b: bammLpStart - iPair.balanceOf(bamm),
            err: "// THEN: expected lp to be unwrapped does not match state"
        });
        assertEq({
            a: iToken0.balanceOf(bamm),
            b: expToken0Owed + uint256(action.token0Amount) + expToken0Swap,
            err: "// THEN: expected token0 balance bamm does not match state"
        });
        assertEq({
            a: int256(iToken1.balanceOf(bamm)),
            b: int256(expToken1Owed) + action.token1Amount - 1e18,
            err: "// THEN: expected token1 balance bamm does not match state"
        });
        assertEq({ a: vault.rented, b: action.rent, err: "// THEN: vault rented does not match input" });
        assertEq({
            a: uint256(vault.token0),
            b: iToken0.balanceOf(bamm),
            err: "// THEN: vault accounting token0 does not match state"
        });
        assertEq({
            a: uint256(vault.token1),
            b: iToken1.balanceOf(bamm),
            err: "// THEN: vault accounting token1 does not match state"
        });
        assertEq({
            a: iBamm.sqrtRented(),
            b: vault.rented,
            err: "// THEN: vault rented does not match bamm sqrtRented"
        });
    }

    function _amountOutPostLpUnwind(uint256 lpUnwound, uint256 amountIn, address tokenIn) public returns (uint256) {
        (uint256 deltaA, uint256 deltaB) = _calculateTokensFromLp(lpUnwound, false);
        (uint256 _reserve0, uint256 _reserve1, , ) = iBamm.addInterest();
        uint256 fee = iPair.fee();
        address token0 = address(iBamm.token0());

        uint112 reserve0 = uint112(_reserve0 - deltaA);
        uint112 reserve1 = uint112(_reserve1 - deltaB);

        (uint112 reserveIn, uint112 reserveOut) = tokenIn == token0 ? (reserve0, reserve1) : (reserve1, reserve0);
        require(amountIn > 0 && reserveIn > 0 && reserveOut > 0); // INSUFFICIENT_INPUT_AMOUNT, INSUFFICIENT_LIQUIDITY
        uint256 amountInWithFee = amountIn * fee;
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = (reserveIn * 10_000) + amountInWithFee;
        return numerator / denominator;
    }
}
