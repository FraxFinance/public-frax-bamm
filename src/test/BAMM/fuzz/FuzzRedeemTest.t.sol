// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import "../../helpers/BAMMTestHelper.sol";

contract FuzzRedeemTest is BAMMTestHelper {
    function setUp() public {
        defaultSetup();
    }

    function testFuzz_Redeem_PreexistingFees_succeeds(
        uint256 amountLpDeposited,
        uint256 amountBammMinted,
        uint256 amountBammRedeemed
    ) public {
        //==============================================================================
        // Arrange
        //==============================================================================

        /// GIVEN: user has minted bamm
        amountLpDeposited = bound(amountLpDeposited, iBamm.MINIMUM_LIQUIDITY(), iPair.balanceOf(tester));
        _bamm_mint({ _bamm: bamm, _user: tester, _to: tester, _pair: pair, _amountPair: amountLpDeposited });
        amountBammMinted = bound(amountBammMinted, 1, iBammErc20.balanceOf(tester));

        //==============================================================================
        // Act
        //==============================================================================
        AccountStorageSnapshot memory testerAccountBefore = accountStorageSnapshot({ _account: tester, _bamm: bamm });
        AccountStorageSnapshot memory bammAccountBefore = accountStorageSnapshot({ _account: bamm, _bamm: bamm });

        /// WHEN: user redeems bamm
        amountBammRedeemed = bound(amountBammRedeemed, 1, amountBammMinted);
        uint256 lpOwed = _calculateBammToLP(amountBammRedeemed);
        vm.startPrank(tester);
        iBamm.redeem(tester, amountBammRedeemed);

        DeltaAccountStorageSnapshot memory testerAccountDelta = deltaAccountStorageSnapshot(testerAccountBefore);
        DeltaAccountStorageSnapshot memory bammAccountDelta = deltaAccountStorageSnapshot(bammAccountBefore);

        //==============================================================================
        // Assert
        //==============================================================================

        assertEq({
            a: testerAccountDelta.delta.bammTokenSnapshot.balanceOf,
            b: amountBammRedeemed,
            err: "/// THEN: incorrect amount of bamm redeemed"
        });
        assertEq({
            a: testerAccountDelta.delta.pairSnapshot.balanceOf,
            b: lpOwed,
            err: "/// THEN: incorrect pair balance of tester"
        });
        assertEq({
            a: bammAccountDelta.delta.pairSnapshot.balanceOf,
            b: lpOwed,
            err: "/// THEN: incorrect pair balance in bamm"
        });
    }

    function testFuzz_Redeem_With_Interest_Earned(uint256 amountBammRedeemed, uint256 time) public {
        //==============================================================================
        // Arrange
        //==============================================================================

        /// GIVEN: user has minted bamm
        uint256 lpMintAmount = iPair.balanceOf(tester) / 4;
        _bamm_mint({ _bamm: bamm, _user: tester, _to: tester, _pair: pair, _amountPair: lpMintAmount });
        uint256 amountBammMinted = iBammErc20.balanceOf(tester);

        _bamm_deposit({
            _bamm: bamm,
            _token0: token0,
            _token1: token1,
            _user: tester2,
            _token0Amount: 5000e18,
            _token1Amount: 5000e18
        });

        IBAMM.Action memory action;
        action.rent = 10e18;

        vm.prank(tester2);
        iBamm.executeActions(action);

        time = uint32(bound(time, 1 days, 90 days));

        vm.warp(block.timestamp + time);

        action.rent = 0;
        action.closePosition = true;
        vm.prank(tester2);
        iBamm.executeActions(action);
        //==============================================================================
        // Act
        //==============================================================================
        AccountStorageSnapshot memory testerAccountBefore = accountStorageSnapshot({ _account: tester, _bamm: bamm });
        AccountStorageSnapshot memory bammAccountBefore = accountStorageSnapshot({ _account: bamm, _bamm: bamm });

        /// WHEN: user redeems bamm
        amountBammRedeemed = bound(amountBammRedeemed, 1, amountBammMinted);
        uint256 lpOwed = _calculateBammToLP(amountBammRedeemed);
        vm.startPrank(tester);
        iBamm.redeem(tester, amountBammRedeemed);

        DeltaAccountStorageSnapshot memory testerAccountDelta = deltaAccountStorageSnapshot(testerAccountBefore);
        DeltaAccountStorageSnapshot memory bammAccountDelta = deltaAccountStorageSnapshot(bammAccountBefore);

        //==============================================================================
        // Assert
        //==============================================================================

        assertEq({
            a: testerAccountDelta.delta.bammTokenSnapshot.balanceOf,
            b: amountBammRedeemed,
            err: "/// THEN: incorrect amount of bamm redeemed"
        });
        assertEq({
            a: testerAccountDelta.delta.pairSnapshot.balanceOf,
            b: lpOwed,
            err: "/// THEN: incorrect pair balance of tester"
        });
        assertEq({
            a: bammAccountDelta.delta.pairSnapshot.balanceOf,
            b: lpOwed,
            err: "/// THEN: incorrect pair balance in bamm"
        });
    }
}
