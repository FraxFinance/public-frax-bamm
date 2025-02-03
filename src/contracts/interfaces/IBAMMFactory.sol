pragma solidity ^0.8.0;

import { IFraxswapFactory } from "dev-fraxswap/src/contracts/core/interfaces/IFraxswapFactory.sol";

interface IBAMMFactory {
    // State variables
    function iFraxswapFactory() external view returns (IFraxswapFactory);
    function routerMultihop() external view returns (address);
    function fraxswapOracle() external view returns (address);
    function variableInterestRate() external view returns (address);
    function isBamm(address bamm) external view returns (bool exists);
    function pairToBamm(address pair) external view returns (address bamm);
    function feeTo() external view returns (address);

    // Functions
    function version() external pure returns (uint256 _major, uint256 _minor, uint256 _patch);
    function createBamm(address _pair) external returns (address bamm);
    function bammsArray() external view returns (address[] memory);
    function bammsLength() external view returns (uint256);
    function setFeeTo(address _feeTo) external;

    // Events
    event BammCreated(address pair, address bamm);

    // Errors
    error Create2Failed();
    error BammAlreadyCreated();
    error PairNotFromFraxswapFactory();
    error NotBAMM();
}
