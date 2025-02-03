// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import "../../helpers/BAMMTestHelper.sol";

contract FuzzMaxUtilityTest is BAMMTestHelper {
    uint256 maxRent;

    function setUp() public {
        defaultSetup();
        // Initialize a clean, balanced pair
        _createFreshBamm();

        uint256 amountPair = iPair.balanceOf(tester) / 2;
        _bamm_mint({ _bamm: bamm, _user: tester, _to: tester, _pair: pair, _amountPair: amountPair });
        uint256 totalAvailableToRent = _calculateLPToBamm(amountPair);
        maxRent = (totalAvailableToRent * 9) / 10;

        _bamm_deposit({
            _bamm: bamm,
            _user: tester2,
            _token0: token0,
            _token1: token1,
            _token0Amount: 1e18,
            _token1Amount: 1e18
        });
    }

    function testFuzz_MaxUtility_AfterLPMint(uint256 _rent, uint256 _amountDeposited) public {
        _rent = bound(_rent, 1, maxRent);
        _amountDeposited = bound(_amountDeposited, 1e18, 1e25);

        _bamm_rent({ _bamm: bamm, _user: tester2, _rent: int256(_rent) });

        uint256 utilityRateBefore = currentUtilityRate();

        deal(token0, pair, _amountDeposited);
        deal(token1, pair, _amountDeposited);
        iPair.mint(tester);

        assertEq({ a: utilityRateBefore, b: currentUtilityRate(), err: "Utility rate has changed" });
    }

    function testFuzz_MaxUtility_AfterLPBurn(uint256 _rent, uint256 _amountBurned) public {
        _rent = bound(_rent, 1, maxRent);
        _amountBurned = bound(_amountBurned, 1, iPair.balanceOf(tester));

        _bamm_rent({ _bamm: bamm, _user: tester2, _rent: int256(_rent) });

        uint256 utilityRateBefore = currentUtilityRate();

        vm.startPrank(tester);
        iPair.transfer(pair, _rent);
        iPair.burn(tester);
        vm.stopPrank();

        assertEq({ a: utilityRateBefore, b: currentUtilityRate(), err: "Utility rate has changed" });
    }
}
