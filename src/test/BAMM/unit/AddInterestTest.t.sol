// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import "../../BaseTest.t.sol";
import "../../helpers/BAMMTestHelper.sol";

contract AddInterestTest is BAMMTestHelper {
    address public lender;
    address public borrower;

    function setUp() public virtual {
        defaultSetup();

        lender = tester;
        borrower = tester2;
        vm.label(lender, "Lender");
        vm.label(borrower, "Borrower");
        vm.label(feeTo, "FeeTo");
    }

    function test_AddInterest_BeforeRent_succeeds() public {
        /*
        On first call
            - timeSinceLastInterestPayment updates
        On second call in same block
            - timeSinceLastInterestPayment remains same
        On third call in new block/timestamp
            - timeSinceLastInterestPayment updates again
        */
        _createFreshBamm();

        uint256 initTimestamp = block.timestamp;
        assertGt(initTimestamp, 0);
        assertEq(iBamm.timeSinceLastInterestPayment(), initTimestamp, "should start at 0");

        /// GIVEN: fast-fwd
        mineBlocksBySecond(100);

        /// GIVEN: lender has minted bamm
        uint256 lpMinted = iPair.balanceOf(lender);
        _bamm_mint({ _bamm: bamm, _user: lender, _to: lender, _pair: pair, _amountPair: lpMinted });

        uint256 firstTimestamp = block.timestamp;
        assertTrue(firstTimestamp > initTimestamp);
        assertEq(iBamm.timeSinceLastInterestPayment(), firstTimestamp, "should sync with first ts");

        /// GIVEN: second call in same block
        _bamm_deposit({
            _bamm: bamm,
            _token0: token0,
            _token1: token1,
            _user: borrower,
            _token0Amount: 1e17,
            _token1Amount: 0
        });

        // stays the same
        assertEq(iBamm.timeSinceLastInterestPayment(), firstTimestamp, "should not have changed");

        /// GIVEN: fast-fwd
        mineBlocksBySecond(100);

        /// GIVEN: third call in new block
        _bamm_deposit({
            _bamm: bamm,
            _token0: token0,
            _token1: token1,
            _user: borrower,
            _token0Amount: 1e17,
            _token1Amount: 0
        });

        uint256 secondTimestamp = block.timestamp;
        assertTrue(secondTimestamp > firstTimestamp);
        assertEq(iBamm.timeSinceLastInterestPayment(), secondTimestamp, "does not equal second timestamp");
    }

    function test_AddInterest_succeeds() public {
        /* 
        *interest has accrued from full utility*
        on first call
            - mints amount to owner
            - safely increases rent multiplier
            - updates timeSinceLastInterestPayment
        borrower closes
        Lender and bamm owner can both redeem 100% of their token
        */

        //==============================================================================
        // Arrange
        //==============================================================================
        _createFreshBamm();

        /// GIVEN: Tester mints as much as they can
        uint256 lenderPairBalanceBefore = iPair.balanceOf(lender);
        _bamm_mint({ _bamm: bamm, _user: lender, _to: lender, _pair: pair, _amountPair: lenderPairBalanceBefore });

        console.log("lenderPairBalanceBefore", lenderPairBalanceBefore);
        console.log("bammReceived", iBammErc20.balanceOf(lender));
        /// @notice `_calculateLPToBamm` can be called after mint given `sqrtRentedReal` = 0
        uint256 totalAvailableToRent = _calculateLPToBamm(lenderPairBalanceBefore);

        /// GIVEN: user deposits
        /// @notice Given `rentMultiplier`: 1e18 bamm token amount is equivalent to available rent
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

        /// GIVEN: user rents
        _bamm_rent({ _bamm: bamm, _user: borrower, _rent: int256(rentAmount) });

        //==============================================================================
        // Act
        //==============================================================================

        // fast-fwd and accrue interest
        mineBlocksBySecond(30 days);
        iBamm.addInterest();

        IBAMM.Action memory action;
        action.closePosition = true;
        vm.prank(borrower);
        iBamm.executeActions(action);

        // lender and interest payee can both redeem all of their tokens
        assertRedeemForLenderAndFeeTo({
            _lenderPairBalanceBefore: lenderPairBalanceBefore,
            _feeToPairBalanceBefore: iPair.balanceOf(feeTo)
        });
    }

    function test_AddInterest_FeesOff_succeeds() public {
        //==============================================================================
        // Arrange
        //==============================================================================

        /// GIVEN: fees are turned off
        vm.prank(iBammFactory.owner());
        iBammFactory.setFeeTo(address(0));

        /// GIVEN: lender has minted bamm
        uint256 lpMinted = iPair.balanceOf(lender);
        _bamm_mint({ _bamm: bamm, _user: lender, _to: lender, _pair: pair, _amountPair: lpMinted });

        /// GIVEN: borrower deposits token0 as collateral
        _bamm_deposit({
            _bamm: bamm,
            _token0: token0,
            _token1: token1,
            _user: borrower,
            _token0Amount: 1e19,
            _token1Amount: 0
        });

        /// GIVEN: borrower rents 1 unit
        _bamm_rent({ _bamm: bamm, _user: borrower, _rent: int256(1e18) });

        //==============================================================================
        // Act
        //==============================================================================

        uint256 supplyBefore = iBammErc20.totalSupply();
        /// WHEN: after time passes, bamm erc20 supply stays the same
        mineBlocksBySecond(30 days);
        iBamm.addInterest();

        //==============================================================================
        // Assert
        //==============================================================================

        assertEq({ a: iBammErc20.totalSupply(), b: supplyBefore, err: "bamm fee should be off" });
    }

    function test_AddInterest_AfterLPMintWithFee_succeeds() public {
        /*
        1. Lender deposits and borrower rents
        2. Assert that kLast > 0 and fee is on to pair to trigger pair._mintFee()
        3. Time passes, interest accrues, then more time passes
        4. User calls pair.mint() and then interest is distributed to owner
            - owner of the pair should have received more LP token
            - Price per share should increase
        5. Borrower can payback rent
        6. Lender and owner can both redeem their interest, BAMM balances cleared
        */
        //==============================================================================
        // Arrange
        //==============================================================================
        _createFreshBamm();

        // set fees on
        vm.startPrank(iPairFactory.feeToSetter());
        iPairFactory.setFeeTo(feeTo);
        vm.stopPrank();

        address minter = alice;

        //==============================================================================
        // Act
        //==============================================================================

        // 1.

        /// GIVEN: Lender deposits
        uint256 lenderPairBalanceBefore = iPair.balanceOf(lender);
        uint256 lpMinted = lenderPairBalanceBefore / 2;
        _bamm_mint({ _bamm: bamm, _user: lender, _to: lender, _pair: pair, _amountPair: lpMinted });

        /// @notice `_calculateLPToBamm` can be called after mint given `sqrtRentedReal` = 0
        uint256 totalAvailableToRent = _calculateLPToBamm(lpMinted);

        /// GIVEN: Borrower deposits
        /// @notice Given `rentMultiplier`: 1e18 bamm token amount is equivalent to available rent
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

        /// GIVEN: Borrower rents
        _bamm_rent({ _bamm: bamm, _user: borrower, _rent: int256(rentAmount) });

        // 2.

        assertGt(iPair.kLast(), 0);
        assertTrue(iPairFactory.feeTo() == feeTo);
        assertTrue(feeTo != address(0));

        // 3.

        mineBlocksBySecond(7 days);
        iBamm.addInterest();
        mineBlocksBySecond(7 days);

        // 4.

        uint256 pricePerShareBefore = pricePerShare();
        uint256 ownerBammBalanceBefore = iBammErc20.balanceOf(feeTo);

        ERC20Mock(token0).mint(pair, 1e18);
        ERC20Mock(token1).mint(pair, 1e18);
        iPair.mint(minter);
        iBamm.addInterest();

        assertGt(pricePerShare(), pricePerShareBefore);
        assertGt(iBammErc20.balanceOf(feeTo), ownerBammBalanceBefore);

        // 5.

        IBAMM.Action memory action;
        action.closePosition = true;
        vm.startPrank(borrower);
        iBamm.executeActions(action);
        vm.stopPrank();

        // 6.

        assertRedeemForLenderAndFeeTo({
            _lenderPairBalanceBefore: lenderPairBalanceBefore,
            _feeToPairBalanceBefore: iPair.balanceOf(feeTo)
        });

        assertEq(iBammErc20.totalSupply(), iBamm.MINIMUM_LIQUIDITY());
    }

    function test_AddInterest_AfterLPBurnWithFee_succeeds() public {
        /*
        1. Future burner has significant amount of supply
        2. Lender deposits and borrower rents
        3. Assert that kLast > 0 and fee is on to pair to trigger pair._mintFee()
        4. Time passes, interest accrues, then more time passes
        5. User calls pair.burn() and then interest is distributed to owner
            - owner of the pair should have received more LP token
            - Price per share should still increase
        6. Borrower can payback rent
        7. Lender and owner can both redeem their interest
        */
        //==============================================================================
        // Arrange
        //==============================================================================
        _createFreshBamm();

        // set fees on
        vm.startPrank(iPairFactory.feeToSetter());
        iPairFactory.setFeeTo(feeTo);
        vm.stopPrank();

        // 1.

        // Give a significant amount of supply to burner (over 33%)
        address burner = alice;
        vm.startPrank(lender);
        iPair.transfer(burner, iPair.balanceOf(lender) / 2);
        assertGt(iPair.balanceOf(burner) * 3, iPair.totalSupply());
        vm.stopPrank();

        //==============================================================================
        // Act
        //==============================================================================

        // 2.

        /// GIVEN: Lender deposits
        uint256 lenderPairBalanceBefore = iPair.balanceOf(lender);
        _bamm_mint({ _bamm: bamm, _user: lender, _to: lender, _pair: pair, _amountPair: lenderPairBalanceBefore });

        /// @notice `_calculateLPToBamm` can be called after mint given `sqrtRentedReal` = 0
        uint256 totalAvailableToRent = _calculateLPToBamm(lenderPairBalanceBefore);

        /// GIVEN: Borrower deposits
        /// @notice Given `rentMultiplier`: 1e18 bamm token amount is equivalent to available rent
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

        /// GIVEN: Borrower rents
        _bamm_rent({ _bamm: bamm, _user: borrower, _rent: int256(rentAmount) });

        // 3.

        assertGt(iPair.kLast(), 0);
        assertTrue(iPairFactory.feeTo() == feeTo);
        assertTrue(feeTo != address(0));

        // 4.

        mineBlocksBySecond(7 days);
        iBamm.addInterest();
        mineBlocksBySecond(7 days);

        // 5.

        uint256 pricePerShareBefore = pricePerShare();
        uint256 ownerBammBalanceBefore = iBammErc20.balanceOf(feeTo);

        vm.startPrank(burner);
        iPair.transfer(pair, iPair.balanceOf(burner));
        iPair.burn(burner);
        vm.stopPrank();
        iBamm.addInterest();

        assertGt(pricePerShare(), pricePerShareBefore);
        assertGt(iBammErc20.balanceOf(feeTo), ownerBammBalanceBefore);

        // 6.

        IBAMM.Action memory action;
        action.closePosition = true;
        vm.startPrank(borrower);
        iBamm.executeActions(action);
        vm.stopPrank();

        // 7.

        assertRedeemForLenderAndFeeTo({
            _lenderPairBalanceBefore: lenderPairBalanceBefore,
            _feeToPairBalanceBefore: iPair.balanceOf(feeTo)
        });

        assertEq(iBammErc20.totalSupply(), iBamm.MINIMUM_LIQUIDITY());
    }

    function assertRedeemForLenderAndFeeTo(uint256 _lenderPairBalanceBefore, uint256 _feeToPairBalanceBefore) public {
        // Lender redeems and receives more LP than before (due to interest)
        vm.startPrank(lender);
        iBamm.redeem(lender, iBammErc20.balanceOf(lender));
        vm.stopPrank();

        assertGt(iPair.balanceOf(lender), _lenderPairBalanceBefore);

        // FeeTo redeems and receives more LP than before (due to interest)
        vm.startPrank(iBammFactory.feeTo());
        iBamm.redeem(iBammFactory.feeTo(), iBammErc20.balanceOf(iBammFactory.feeTo()));
        vm.stopPrank();

        assertGt(iPair.balanceOf(feeTo), _feeToPairBalanceBefore);
    }

    function pricePerShare() public view returns (uint256 pps) {
        (uint256 reserve0, uint256 reserve1, ) = iPair.getReserves();
        uint256 pairTotalSupply = iPair.totalSupply();

        uint256 balance = IERC20(pair).balanceOf(bamm);
        uint256 sqrtBalance = calcSqrtAmount(balance, pairTotalSupply, reserve0, reserve1);
        uint256 sqrtRentedReal = (uint256(iBamm.sqrtRented()) * iBamm.rentedMultiplier()) / 1e18;
        pps = ((sqrtBalance + sqrtRentedReal) * 1e18) / iBammErc20.totalSupply();
    }

    function calcSqrtAmount(
        uint256 balance,
        uint256 pairTotalSupply,
        uint256 reserve0,
        uint256 reserve1
    ) internal pure returns (uint256 sqrtAmount) {
        uint256 K = reserve0 * reserve1;
        if (K < 2 ** 140) sqrtAmount = Math.sqrt((((K * balance) / pairTotalSupply) * balance) / pairTotalSupply);
        else sqrtAmount = (Math.sqrt(K) * balance) / pairTotalSupply;
    }
}
