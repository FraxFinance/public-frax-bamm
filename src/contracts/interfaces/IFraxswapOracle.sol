pragma solidity ^0.8.0;

import { IFraxswapPair } from "dev-fraxswap/src/contracts/core/interfaces/IFraxswapPair.sol";

interface IFraxswapOracle {
    function getPrice(
        IFraxswapPair pool,
        uint256 period,
        uint256 rounds,
        uint256 maxDiffPerc
    ) external view returns (uint256 result0, uint256 result1);

    function getPrice0(
        IFraxswapPair pool,
        uint256 period,
        uint256 rounds,
        uint256 maxDiffPerc
    ) external view returns (uint256 result0);

    function getPrice1(
        IFraxswapPair pool,
        uint256 period,
        uint256 rounds,
        uint256 maxDiffPerc
    ) external view returns (uint256 result1);

    function mulDecode(uint224 value) external pure returns (uint256 result);
}
