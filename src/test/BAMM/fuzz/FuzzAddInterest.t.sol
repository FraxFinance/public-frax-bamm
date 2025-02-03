// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import "../../helpers/BAMMTestHelper.sol";

contract FuzzAddInterestTest is BAMMTestHelper {
    function setUp() public {
        defaultSetup();
    }

    /**
     * Possible State Inputs to `_addInterest()`
     *
     *     uint256 timeSinceLastInterestPayment,
     *     uint256 sqrtRented,
     *     uint256 rentMultiplier,
     *     uint256 lpPairTS,
     *     uint256 lpBalanceOfBamm,
     *     uint256 reserveA,
     *     uint256 reserveB
     */
    function testFuzzAddInterest(
        uint256 timeSinceLastInterestPayment,
        uint256 sqrtRented,
        uint256 rentMultiplier,
        uint256 lpPairTS,
        uint256 lpBalanceOfBamm,
        uint256 reserveA,
        uint256 reserveB
    ) public {
        // Assume that the bamms balance and total supply are locked
        lpPairTS = bound(lpPairTS, 3000, 50_000_000e18);

        // Assume That reserveA and Reserve B are half the uint112 value
        if (reserveA > type(uint112).max / 2) reserveA = type(uint112).max / 2;
        if (reserveB > type(uint112).max / 2) reserveB = type(uint112).max / 2;

        // Assume that neither reserveA and resvereB == 0 when other is > 0
        if (reserveA == 0 && reserveB != 0) reserveA = reserveB;
        if (reserveB == 0 && reserveA != 0) reserveB = reserveA;
        if (reserveA == 0 && reserveB == 0) reserveA = reserveB = lpPairTS;

        // Assume that lp total supply floor is the lower about of the reserves
        if (lpPairTS == 0 && (reserveB != 0 || reserveA != 0)) lpPairTS = reserveA < reserveB ? reserveA : reserveB;

        // Assume sqrtRented is gte ts
        if (sqrtRented > lpPairTS) sqrtRented = lpPairTS - 3000;
        if (lpBalanceOfBamm > lpPairTS) lpBalanceOfBamm = lpPairTS;

        // Assume `timeSinceLastInterestPayment` is always less than block.timestamp
        if (timeSinceLastInterestPayment > block.timestamp) timeSinceLastInterestPayment = block.timestamp;
        timeSinceLastInterestPayment = block.timestamp - timeSinceLastInterestPayment;

        // Assume rentMultiplier's floor is 1e18
        if (rentMultiplier < 1e18) rentMultiplier = 1e18;

        // Assume `sqrtRented` is less than 20 M
        if (sqrtRented > 20_000_000e18) sqrtRented = 20_000_000e18;

        // Assume that the rentMultiplier is less than type(uint256).max / 2
        if (rentMultiplier > type(uint256).max / 1e35) rentMultiplier = type(uint256).max / 1e35;

        console.log("timeSinceLastInterestPayment", timeSinceLastInterestPayment);
        console.log("sqrtRented", sqrtRented);
        console.log("rentMultiplier", rentMultiplier);
        console.log("lpPairTS", lpPairTS);
        console.log("lpBalanceOfBamm", lpBalanceOfBamm);
        console.log("reserveA", reserveA);
        console.log("reserveB", reserveB);

        /// SET VALUES FOR TEST
        vm.store(address(iBamm), bytes32(uint256(3)), bytes32(rentMultiplier));
        vm.store(address(iBamm), bytes32(uint256(2)), bytes32(sqrtRented));
        vm.store(address(iBamm), bytes32(uint256(4)), bytes32(timeSinceLastInterestPayment));

        vm.mockCall(
            address(iPair),
            abi.encodeWithSignature("balanceOf(address)", address(iBamm)),
            abi.encode(lpBalanceOfBamm)
        );
        vm.mockCall(address(iPair), abi.encodeWithSignature("totalSupply()"), abi.encode(lpPairTS));
        vm.mockCall(address(iPair), abi.encodeWithSignature("getReserves()"), abi.encode(reserveA, reserveB, 0));

        iBamm.addInterest();
    }
}
