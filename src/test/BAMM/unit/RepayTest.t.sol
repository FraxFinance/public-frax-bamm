// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import "src/test/BAMM/unit/BAMMInvariants.t.sol";

contract RepayRentTest is BAMMTestHelper {
    uint256 totalAvailableToRent;
    uint256 lpMinted;

    function setUp() public {
        defaultSetup();
        lpMinted = iPair.balanceOf(tester);
        _bamm_mint({ _bamm: bamm, _user: tester, _to: tester, _pair: pair, _amountPair: lpMinted });
        /// @notice `_calculateLPToBamm` can be called after mint given `sqrtRentedReal` = 0
        totalAvailableToRent = _calculateLPToBamm(lpMinted);
    }

    function test_Repay_ClosePosition_succeeds() public {
        _bamm_deposit({
            _bamm: bamm,
            _token0: token0,
            _token1: token1,
            _user: tester2,
            _token0Amount: 100e18,
            _token1Amount: 100e18
        });

        _bamm_rent({ _bamm: bamm, _user: tester2, _rent: int256(100e18) });

        vm.warp(block.timestamp + 30 days);
        iBamm.addInterest();

        uint256 lpOwedToBamm = _calculateLpFromRent(uint256(100e18), true);
        uint256 lpBammBefore = iPair.balanceOf(bamm);

        IBAMM.Action memory action;
        action.closePosition = true;

        vm.prank(tester2);
        iBamm.executeActions(action);

        assertEq({
            a: lpOwedToBamm,
            b: iPair.balanceOf(bamm) - lpBammBefore,
            err: "// THEN: lp balance of bamm not as expected"
        });
    }

    function test_Repay_PoolBalanceChangedAndClosePosition_noInterest_succeeds() public {
        _bamm_deposit({
            _bamm: bamm,
            _token0: token0,
            _token1: token1,
            _user: tester2,
            _token0Amount: 100e18,
            _token1Amount: 100e18
        });

        _bamm_rent({ _bamm: bamm, _user: tester2, _rent: int256(100e18) });

        uint256 bammBalanceBefore = iPair.balanceOf(bamm);
        (int256 token0VaultBal, int256 token1VaultBal, ) = iBamm.userVaults(tester2);

        // Simulate net trade direction
        marketBuy(10_000e18);

        IBAMM.Action memory action;
        action.closePosition = true;

        uint256 lpFromRent = _calculateLpFromRent(100e18, true);
        (uint256 token0ToRepay, uint256 token1ToRepay) = _calculateTokensFromLp(lpFromRent, true);

        vm.prank(tester2);
        iBamm.executeActions(action);

        assertEq({
            a: iToken0.balanceOf(tester2),
            b: uint256(token0VaultBal) - token0ToRepay,
            err: "// THEN: Token0 balance not expected"
        });

        assertEq({
            a: iToken1.balanceOf(tester2),
            b: uint256(token1VaultBal) - token1ToRepay,
            err: "// THEN: Token1 balance not expected"
        });

        assertEq({
            a: iPair.balanceOf(bamm),
            b: lpFromRent + bammBalanceBefore,
            err: "// THEN: LP balance of bamm not expected"
        });
    }

    function test_Repay_PoolBalanceChanged_noInterest_succeeds() public {
        _bamm_deposit({
            _bamm: bamm,
            _token0: token0,
            _token1: token1,
            _user: tester2,
            _token0Amount: 100e18,
            _token1Amount: 100e18
        });

        _bamm_rent({ _bamm: bamm, _user: tester2, _rent: int256(100e18) });

        uint256 bammBalanceBefore = iPair.balanceOf(bamm);
        (int256 token0VaultBal, int256 token1VaultBal, ) = iBamm.userVaults(tester2);

        // Simulate net trade direction
        marketBuy(10_000e18);

        IBAMM.Action memory action;
        action.rent = -50e18;

        uint256 lpFromRent = _calculateLpFromRent(50e18, true);
        (uint256 token0ToRepay, uint256 token1ToRepay) = _calculateTokensFromLp(lpFromRent, true);

        vm.prank(tester2);
        iBamm.executeActions(action);

        (int256 token0VaultBalAfter, int256 token1VaultBalAfter, ) = iBamm.userVaults(tester2);

        assertEq({
            a: uint256(token0VaultBalAfter),
            b: uint256(token0VaultBal) - token0ToRepay,
            err: "// THEN: Token0 balance not expected"
        });

        assertEq({
            a: uint256(token1VaultBalAfter),
            b: uint256(token1VaultBal) - token1ToRepay,
            err: "// THEN: Token1 balance not expected"
        });

        assertEq({
            a: iPair.balanceOf(bamm),
            b: lpFromRent + bammBalanceBefore,
            err: "// THEN: LP balance of bamm not expected"
        });
    }

    function test_Repay_PoolBalanceChangedAndClosePosition_Interest_succeeds() public {
        _bamm_deposit({
            _bamm: bamm,
            _token0: token0,
            _token1: token1,
            _user: tester2,
            _token0Amount: 100e18,
            _token1Amount: 100e18
        });

        _bamm_rent({ _bamm: bamm, _user: tester2, _rent: int256(100e18) });

        vm.warp(block.timestamp + 30 days);
        iBamm.addInterest();

        uint256 bammBalanceBefore = iPair.balanceOf(bamm);
        (int256 token0VaultBal, int256 token1VaultBal, ) = iBamm.userVaults(tester2);

        // Simulate net trade direction
        marketBuy(10_000e18);

        IBAMM.Action memory action;
        action.closePosition = true;

        uint256 lpFromRent = _calculateLpFromRent(100e18, true);
        (uint256 token0ToRepay, uint256 token1ToRepay) = _calculateTokensFromLp(lpFromRent, true);

        vm.prank(tester2);
        iBamm.executeActions(action);

        assertEq({
            a: iToken0.balanceOf(tester2),
            b: uint256(token0VaultBal) - token0ToRepay,
            err: "// THEN: Token0 balance not expected"
        });

        assertEq({
            a: iToken1.balanceOf(tester2),
            b: uint256(token1VaultBal) - token1ToRepay,
            err: "// THEN: Token1 balance not expected"
        });

        assertEq({
            a: iPair.balanceOf(bamm),
            b: lpFromRent + bammBalanceBefore,
            err: "// THEN: LP balance of bamm not expected"
        });
    }

    function test_Repay_PoolBalanceChanged_Interest_succeeds() public {
        _bamm_deposit({
            _bamm: bamm,
            _token0: token0,
            _token1: token1,
            _user: tester2,
            _token0Amount: 100e18,
            _token1Amount: 100e18
        });

        _bamm_rent({ _bamm: bamm, _user: tester2, _rent: int256(100e18) });

        vm.warp(block.timestamp + 30 days);
        iBamm.addInterest();

        uint256 bammBalanceBefore = iPair.balanceOf(bamm);
        (int256 token0VaultBal, int256 token1VaultBal, ) = iBamm.userVaults(tester2);

        // Simulate net trade direction
        marketBuy(10_000e18);

        IBAMM.Action memory action;
        action.rent = -50e18;

        uint256 lpFromRent = _calculateLpFromRent(50e18, true);
        (uint256 token0ToRepay, uint256 token1ToRepay) = _calculateTokensFromLp(lpFromRent, true);

        vm.prank(tester2);
        iBamm.executeActions(action);

        (int256 token0VaultBalAfter, int256 token1VaultBalAfter, ) = iBamm.userVaults(tester2);

        assertEq({
            a: uint256(token0VaultBalAfter),
            b: uint256(token0VaultBal) - token0ToRepay,
            err: "// THEN: Token0 balance not expected"
        });

        assertEq({
            a: uint256(token1VaultBalAfter),
            b: uint256(token1VaultBal) - token1ToRepay,
            err: "// THEN: Token1 balance not expected"
        });

        assertEq({
            a: iPair.balanceOf(bamm),
            b: lpFromRent + bammBalanceBefore,
            err: "// THEN: LP balance of bamm not expected"
        });
    }

    function test_Repay_InsufficientAmount_token0_reverts() public {
        _bamm_deposit({
            _bamm: bamm,
            _token0: token0,
            _token1: token1,
            _user: tester2,
            _token0Amount: 100e18,
            _token1Amount: 100e18
        });

        _bamm_rent({ _bamm: bamm, _user: tester2, _rent: int256(100e18) });

        uint256 lpFromRent = _calculateLpFromRent(50e18, true);
        (uint256 token0ToRepay, uint256 token1ToRepay) = _calculateTokensFromLp(lpFromRent, true);

        IBAMM.Action memory action;
        action.rent = -50e18;
        action.token0AmountMin = token0ToRepay;
        action.token1AmountMin = token1ToRepay;

        // Simulate front run trade direction
        marketSell(10_000e18);

        // Excpect txn will fail if front run
        vm.expectRevert(IBAMM.InsufficientAmount.selector);
        vm.prank(tester2);
        iBamm.executeActions(action);
    }

    function test_Repay_InsufficientAmount_token1_reverts() public {
        _bamm_deposit({
            _bamm: bamm,
            _token0: token0,
            _token1: token1,
            _user: tester2,
            _token0Amount: 100e18,
            _token1Amount: 100e18
        });

        _bamm_rent({ _bamm: bamm, _user: tester2, _rent: int256(100e18) });

        uint256 lpFromRent = _calculateLpFromRent(50e18, true);
        (uint256 token0ToRepay, uint256 token1ToRepay) = _calculateTokensFromLp(lpFromRent, true);

        IBAMM.Action memory action;
        action.rent = -50e18;
        action.token0AmountMin = token0ToRepay;
        action.token1AmountMin = token1ToRepay;

        // Simulate front run trade direction
        marketBuy(10_000e18);

        // Excpect txn will fail if front run
        vm.expectRevert(IBAMM.InsufficientAmount.selector);
        vm.prank(tester2);
        iBamm.executeActions(action);
    }
}
