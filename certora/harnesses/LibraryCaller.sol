pragma solidity 0.8.23;

import { BitMath } from "src/contracts/libraries/BitMath.sol";
import { FullMath } from "src/contracts/libraries/FullMath.sol";
import { FixedPoint } from "src/contracts/libraries/FixedPoint.sol";

contract LibraryCaller {
    ///////// BitMath ///////////
    function mostSignificantBit(uint256 x) external pure returns (uint8 r) {
        return BitMath.mostSignificantBit(x);
    }

    function leastSignificantBit(uint256 x) external pure returns (uint8 r) {
        return BitMath.leastSignificantBit(x);
    }

    /////////// FullMath /////////

    function mulDiv(uint256 a, uint256 b, uint256 denominator) external pure returns (uint256 result) {
        return FullMath.mulDiv(a, b, denominator);
    }

    function mulDivRoundingUp(uint256 a, uint256 b, uint256 denominator) external pure returns (uint256 result) {
        return FullMath.mulDivRoundingUp(a, b, denominator);
    }

    /////////////// FixedPoint //////////////////

    function encode(uint112 x) external pure returns (FixedPoint.uq112x112 memory) {
        return FixedPoint.encode(x);
    }

    function encode144(uint144 x) external pure returns (FixedPoint.uq144x112 memory) {
        return FixedPoint.encode144(x);
    }

    function decode(FixedPoint.uq112x112 memory self) external pure returns (uint112) {
        return FixedPoint.decode(self);
    }

    function decode144(FixedPoint.uq144x112 memory self) external pure returns (uint144) {
        return FixedPoint.decode144(self);
    }

    function mul(FixedPoint.uq112x112 memory self, uint256 y) external pure returns (FixedPoint.uq144x112 memory) {
        return FixedPoint.mul(self, y);
    }

    function muli(FixedPoint.uq112x112 memory self, int256 y) external pure returns (int256) {
        return FixedPoint.muli(self, y);
    }

    function muluq(
        FixedPoint.uq112x112 memory self,
        FixedPoint.uq112x112 memory other
    ) external pure returns (FixedPoint.uq112x112 memory) {
        return FixedPoint.muluq(self, other);
    }

    function divuq(
        FixedPoint.uq112x112 memory self,
        FixedPoint.uq112x112 memory other
    ) external pure returns (FixedPoint.uq112x112 memory) {
        return FixedPoint.divuq(self, other);
    }

    function fraction(uint256 numerator, uint256 denominator) external pure returns (FixedPoint.uq112x112 memory) {
        return FixedPoint.fraction(numerator, denominator);
    }

    function reciprocal(FixedPoint.uq112x112 memory self) external pure returns (FixedPoint.uq112x112 memory) {
        return FixedPoint.reciprocal(self);
    }

    function sqrt(FixedPoint.uq112x112 memory self) external pure returns (FixedPoint.uq112x112 memory) {
        return FixedPoint.sqrt(self);
    }
}
