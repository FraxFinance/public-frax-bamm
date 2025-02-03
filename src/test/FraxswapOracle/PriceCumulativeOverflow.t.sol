// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "../BaseTest.t.sol";
import "../helpers/BAMMTestHelper.sol";
// import { UQ112x112 } from "src/contracts/utils/UQ112x112.sol";

contract OracleCummulativePriceOverflowTest is BAMMTestHelper {
    using UQ112x112 for uint224;

    function setUp() public virtual {
        defaultSetup();
    }

    function test_oracle_getPrices_call() public returns (uint256, uint256) {
        // vm.warp(type(uint32).max);
        console.log("\n");
        (uint256 reserve0, uint256 reserve1, , ) = iBamm.addInterest();
        (uint256 result0, uint256 result1) = iBammOracle.getPrice({
            pool: iBamm.pair(),
            period: 60 * 30,
            rounds: 10,
            maxDiffPerc: 10_000
        });
        console.log(result0, result1);
        result0 = 1e68 / result0;
        uint256 spotPrice = (uint256(reserve0) * 1e34) / reserve1;

        console.log("The spot price: ", spotPrice);
        uint256 diff = (spotPrice > result0 ? spotPrice - result0 : result0 - spotPrice);
        console.log("The first diff check: ", diff);
        assertFalse(((diff * 10_000) / result0 > 500));
        console.log("   The result of the first check: ", ((diff * 10_000) / result0 > 500));
        diff = (spotPrice > result1 ? spotPrice - result1 : result1 - spotPrice);
        console.log("The second diff check: ", diff);
        assertFalse(((diff * 10_000) / result0 > 500));
        console.log("   The result of the second check: ", (diff * 10_000) / result1 > 500);
        console.log("\n");
        return (reserve0, reserve1);
    }

    function test_overflowCumulative() public {
        test_oracle_getPrices_call();

        IFraxswapPair pair = iBamm.pair();
        bytes32 slot = keccak256(abi.encodePacked(uint256(31)));
        uint256 len = pair.getTWAPHistoryLength() - 1;
        (uint256 resA, uint256 resB, ) = pair.getReserves();
        IFraxswapPair.TWAPObservation memory obsOld = pair.TWAPObservationHistory(len - 1);

        IFraxswapPair.TWAPObservation memory obsCurrent = pair.TWAPObservationHistory(len);

        uint32 estimatedElapsed;
        uint256 modifiedPrice0;
        uint256 modifiedPrice1;
        unchecked {
            estimatedElapsed = uint32(obsCurrent.timestamp - obsOld.timestamp);
            modifiedPrice0 =
                (type(uint256).max -
                    (obsOld.price0CumulativeLast +
                        uint256(UQ112x112.encode(uint112(resB)).uqdiv(uint112(resA))) *
                        estimatedElapsed)) +
                obsOld.price0CumulativeLast +
                uint256(UQ112x112.encode(uint112(resB)).uqdiv(uint112(resA))) *
                estimatedElapsed;
            modifiedPrice1 =
                (type(uint256).max -
                    (obsOld.price1CumulativeLast +
                        uint256(UQ112x112.encode(uint112(resA)).uqdiv(uint112(resB))) *
                        estimatedElapsed)) +
                obsOld.price1CumulativeLast +
                uint256(UQ112x112.encode(uint112(resA)).uqdiv(uint112(resB))) *
                estimatedElapsed;
        }
        vm.store(address(pair), bytes32(uint256(slot) + ((len) * 3) + 1), bytes32(uint256(modifiedPrice0)));
        vm.store(address(pair), bytes32(uint256(slot) + ((len) * 3) + 2), bytes32(uint256(modifiedPrice1)));

        vm.warp(block.timestamp + 20_000);
        (resA, resB, ) = pair.getReserves();
        deal(pair.token0(), address(this), resA);
        deal(pair.token1(), address(this), resB);
        IERC20(pair.token0()).transfer(address(pair), resA);
        IERC20(pair.token1()).transfer(address(pair), resB);
        pair.mint(address(this));

        test_oracle_getPrices_call();
    }

    function test_overflowTimestamp_currentObs() public {
        (uint256 resA, uint256 resB) = test_oracle_getPrices_call();
        // IFraxswapPair pair = IFraxswapPair(iBamm.pair();
        vm.warp(uint256(type(uint32).max) + 1);

        (uint256 result0, uint256 result1) = iBammOracle.getPrice({
            pool: iBamm.pair(),
            period: 60 * 30,
            rounds: 10,
            maxDiffPerc: 10_000
        });
        console.log("Calc'd timestamp: ", block.timestamp % 2 ** 32);
        console.log(result0, result1);
        result0 = 1e68 / result0;
        uint256 spotPrice = (uint256(resA) * 1e34) / resB;

        console.log("The spot price: ", spotPrice);
        uint256 diff = (spotPrice > result0 ? spotPrice - result0 : result0 - spotPrice);
        console.log("The first diff check: ", diff);
        assertFalse(((diff * 10_000) / result0 > 500));
        console.log("   The result of the first check: ", ((diff * 10_000) / result0 > 500));
        diff = (spotPrice > result1 ? spotPrice - result1 : result1 - spotPrice);
        console.log("The second diff check: ", diff);
        assertFalse(((diff * 10_000) / result0 > 500));
        console.log("   The result of the second check: ", (diff * 10_000) / result1 > 500);
        console.log("\n");
    }

    function test_overflowTimestamp_foundObs() public {
        (uint256 resA, uint256 resB) = test_oracle_getPrices_call();
        // IFraxswapPair pair = IFraxswapPair(iBamm.pair();
        vm.warp(18_552);

        IFraxswapPair pair = iBamm.pair();
        bytes32 slot = keccak256(abi.encodePacked(uint256(31)));
        uint256 len = pair.getTWAPHistoryLength() - 1;
        vm.store(address(pair), bytes32(uint256(slot) + ((len) * 3)), bytes32(uint256(0)));

        (uint256 result0, uint256 result1) = iBammOracle.getPrice({
            pool: iBamm.pair(),
            period: 60 * 30,
            rounds: 10,
            maxDiffPerc: 10_000
        });
        // console.log("Calc'd timestamp: ", block.timestamp % 2 ** 32);
        console.log(result0, result1);
        result0 = 1e68 / result0;
        uint256 spotPrice = (uint256(resA) * 1e34) / resB;

        console.log("The spot price: ", spotPrice);
        uint256 diff = (spotPrice > result0 ? spotPrice - result0 : result0 - spotPrice);
        console.log("The first diff check: ", diff);
        assertFalse(((diff * 10_000) / result0 > 500));
        console.log("   The result of the first check: ", ((diff * 10_000) / result0 > 500));
        diff = (spotPrice > result1 ? spotPrice - result1 : result1 - spotPrice);
        console.log("The second diff check: ", diff);
        assertFalse(((diff * 10_000) / result0 > 500));
        console.log("   The result of the second check: ", (diff * 10_000) / result1 > 500);
        console.log("\n");
    }

    function test_overflowTimestamp_foundObs_avoidEdge() public {
        (uint256 resA, uint256 resB) = test_oracle_getPrices_call();
        // IFraxswapPair pair = IFraxswapPair(iBamm.pair();
        vm.warp(18_552);

        IFraxswapPair pair = iBamm.pair();
        bytes32 slot = keccak256(abi.encodePacked(uint256(31)));
        uint256 len = pair.getTWAPHistoryLength() - 1;
        vm.store(address(pair), bytes32(uint256(slot) + ((len) * 3)), bytes32(uint256(1)));

        (uint256 result0, uint256 result1) = iBammOracle.getPrice({
            pool: iBamm.pair(),
            period: 60 * 30,
            rounds: 10,
            maxDiffPerc: 10_000
        });
        // console.log("Calc'd timestamp: ", block.timestamp % 2 ** 32);
        console.log(result0, result1);
        result0 = 1e68 / result0;
        uint256 spotPrice = (uint256(resA) * 1e34) / resB;

        console.log("The spot price: ", spotPrice);
        uint256 diff = (spotPrice > result0 ? spotPrice - result0 : result0 - spotPrice);
        console.log("The first diff check: ", diff);
        assertFalse(((diff * 10_000) / result0 > 500));
        console.log("   The result of the first check: ", ((diff * 10_000) / result0 > 500));
        diff = (spotPrice > result1 ? spotPrice - result1 : result1 - spotPrice);
        console.log("The second diff check: ", diff);
        assertFalse(((diff * 10_000) / result0 > 500));
        console.log("   The result of the second check: ", (diff * 10_000) / result1 > 500);
        console.log("\n");
    }
}

library UQ112x112 {
    uint224 constant Q112 = 2 ** 112;

    // encode a uint112 as a UQ112x112
    function encode(uint112 y) internal pure returns (uint224 z) {
        z = uint224(y) * Q112; // never overflows
    }

    // divide a UQ112x112 by a uint112, returning a UQ112x112
    function uqdiv(uint224 x, uint112 y) internal pure returns (uint224 z) {
        z = x / uint224(y);
    }
}
