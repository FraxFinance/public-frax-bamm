// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import "../../helpers/BAMMTestHelper.sol";

contract FuzzMintTest is BAMMTestHelper {
    function setUp() public {
        defaultSetup();
    }

    function testFuzz_Mint_PreExistingFees_succeeds(uint256 amountLpDeposited) public {
        //==============================================================================
        // Arrange
        //==============================================================================

        /// GIVEN: user wants to mint and contains enough LP tokens
        uint256 balanceBefore = iPair.balanceOf(tester);
        amountLpDeposited = bound(amountLpDeposited, iBamm.MINIMUM_LIQUIDITY(), balanceBefore);

        //==============================================================================
        // Act
        //==============================================================================

        /// WHEN: user mints an amount of bamm
        uint256 bammAmountOwed = _calculateLPToBamm(amountLpDeposited);
        vm.startPrank(tester);
        iPair.approve(bamm, amountLpDeposited);
        iBamm.mint(tester, amountLpDeposited);

        //==============================================================================
        // Assert
        //==============================================================================
        assertEq({ a: iBammErc20.totalSupply(), b: bammAmountOwed, err: "/// THEN: incorrect bamm amount minted" });
        assertEq({
            a: iPair.balanceOf(tester),
            b: balanceBefore - amountLpDeposited,
            err: "/// THEN: incorrect lp amount deposited"
        });
    }

    function testFuzz_Mint_Accounts_With_Interest_Earned(uint256 amountLpDeposited, uint32 time) public {
        //==============================================================================
        // Arrange
        //==============================================================================
        /// GIVEN: user wants to mint and contains enough LP tokens
        _rentMintandRent();

        uint256 balanceBefore = iPair.balanceOf(tester);
        time = uint32(bound(time, 1 days, 90 days));

        vm.warp(block.timestamp + time);

        amountLpDeposited = bound(amountLpDeposited, iBamm.MINIMUM_LIQUIDITY(), (balanceBefore * 3) / 4);

        //==============================================================================
        // Act
        //==============================================================================

        /// WHEN: user mints an amount of bamm
        uint256 bammAmountOwed = _calculateLPToBamm(amountLpDeposited);
        /// @notice Fetch total supply after `addInterest` has been called on bamm
        uint256 totalSupplyBefore = iBammErc20.totalSupply();
        vm.startPrank(tester);
        iPair.approve(bamm, amountLpDeposited);
        iBamm.mint(tester, amountLpDeposited);

        //==============================================================================
        // Assert
        //==============================================================================

        uint256 totalSupplyAfter = iBammErc20.totalSupply();
        console.log(totalSupplyAfter, totalSupplyBefore, bammAmountOwed);
        assertEq({
            a: totalSupplyAfter - totalSupplyBefore,
            b: bammAmountOwed,
            err: "/// THEN: incorrect bamm amount minted"
        });
        assertEq({
            a: iPair.balanceOf(tester),
            b: balanceBefore - amountLpDeposited,
            err: "/// THEN: incorrect lp amount deposited"
        });
    }

    function test_fuzz_mint_event_difference_value(
        uint256 _rentMultiplier,
        uint256 _balance,
        uint256 _sqrtRented,
        uint256 _reserve0,
        uint256 _reserve1,
        uint256 _pairTotalSupply
    ) public {
        // Floor Fuzz Variables, avoid too many global rejects error
        if (_balance == 0) _balance += 1;
        if (_sqrtRented == 0) _sqrtRented += 1;
        if (_pairTotalSupply == 0) _pairTotalSupply += 1;
        if (_reserve0 < 1e6) _reserve0 += 1e6;
        if (_reserve1 < 1e6) _reserve1 += 1e6;
        if (_rentMultiplier < 1e18) _rentMultiplier = 1e18;

        // Assume That reserveA and Reserve B are half the uint112 value
        if (_reserve0 > type(uint112).max / 2) _reserve0 = type(uint112).max / 2;
        if (_reserve1 > type(uint112).max / 2) _reserve1 = type(uint112).max / 2;

        // Assume that neither reserveA and resvereB == 0 when other is > 0
        if (_reserve0 == 0 && _reserve1 != 0) _reserve0 = _reserve1;
        if (_reserve1 == 0 && _reserve0 != 0) _reserve1 = _reserve0;

        // Assume that lp total supply floor is the lower about of the reserves
        if (_pairTotalSupply == 0 && (_reserve1 != 0 || _reserve0 != 0)) {
            _pairTotalSupply = _reserve0 < _reserve1 ? _reserve0 : _reserve1;
        }
        // Assume Total Supply Falls on the constant product invariant
        if (_pairTotalSupply > _reserve0 && _pairTotalSupply > _reserve1) {
            if (_reserve0 > _reserve1) {
                _pairTotalSupply = _reserve1;
            } else {
                _pairTotalSupply = _reserve0;
            }
        }
        // Ceil Fuzz Variables
        if (_balance > _pairTotalSupply) _balance = _pairTotalSupply;
        if (_sqrtRented > _pairTotalSupply || _sqrtRented > _balance) _sqrtRented = (_pairTotalSupply - _balance);
        if (_rentMultiplier > 100_000e18) _rentMultiplier = 100_000e18;

        console.log("RentMultiplier: ", _rentMultiplier);
        console.log("Balance: ", _balance);
        console.log("sqrtRented: ", _sqrtRented);
        console.log("reserve0: ", _reserve0);
        console.log("reserve1: ", _reserve1);
        console.log("pairTotalSupply: ", _pairTotalSupply);

        uint256 rentedMultiplierEvent_ = _rentMultiplier;
        uint256 balance = _balance;

        // BAMM:L#616-L#620
        uint256 sqrtReserveEvent = Math.sqrt(uint256(_reserve0) * _reserve1);
        uint256 sqrtBalanceEvent = _pairTotalSupply == 0 ? 0 : ((balance * sqrtReserveEvent) / _pairTotalSupply);
        uint256 sqrtRentedRealEvent = (uint256(_sqrtRented) * rentedMultiplierEvent_) / 1e18;

        uint256 sqrtBalanceFunction;
        uint256 sqrtReserve = Math.sqrt(uint256(_reserve0) * _reserve1);

        // BAMM: L#268-L#271
        sqrtBalanceFunction = (balance * sqrtReserve) / _pairTotalSupply;
        if ((sqrtBalanceFunction * _pairTotalSupply) / sqrtReserve < balance) sqrtBalanceFunction += 1;
        uint256 sqrtRentedRealFunction = (uint256(_sqrtRented) * _rentMultiplier) / 1e18;
        if ((sqrtRentedRealFunction * 1e18) / _rentMultiplier < uint256(_sqrtRented)) sqrtRentedRealFunction += 1;

        assertApproxEqAbs({ a: sqrtBalanceFunction, b: sqrtBalanceEvent, maxDelta: 1 });

        assertApproxEqAbs({ a: sqrtRentedRealEvent, b: sqrtRentedRealFunction, maxDelta: 1 });
    }

    //==============================================================================
    // Helpers
    //==============================================================================
    function _rentMintandRent() public {
        uint256 balanceBefore = iPair.balanceOf(tester);
        testFuzz_Mint_PreExistingFees_succeeds(balanceBefore / 4);
        vm.stopPrank();

        _bamm_deposit({
            _bamm: bamm,
            _token0: token0,
            _token1: token1,
            _user: tester2,
            _token0Amount: 100e18,
            _token1Amount: 100e18
        });

        IBAMM.Action memory action;
        action.rent = 10e18;

        vm.prank(tester2);
        iBamm.executeActions(action);
    }
}
