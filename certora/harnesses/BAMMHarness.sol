// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import { BAMM } from "src/contracts/BAMM.sol";
//import { FraxMath as Math } from "dev-fraxswap/src/contracts/core/libraries/FraxMath.sol";
import { FullMath } from "src/contracts/libraries/FullMath.sol";
import { Math as FraxMath } from "dev-fraxswap/src/contracts/core/libraries/Math.sol";

import { Math as OZMath } from "@openzeppelin/contracts/utils/math/Math.sol";
import { IFraxswapRouterMultihop } from "dev-fraxswap/src/contracts/periphery/interfaces/IFraxswapRouterMultihop.sol";

contract BAMMHarness is BAMM {
    constructor(bytes memory _encodedBammConstructorArgs) BAMM(_encodedBammConstructorArgs) {}

    function get_sqrtRented() external view returns (int256) {
        return sqrtRented;
    }

    function get_rentedMultiplier() external view returns (uint256) {
        return rentedMultiplier;
    }

    function get_token0() external view returns (address) {
        return address(token0);
    }

    function get_token1() external view returns (address) {
        return address(token1);
    }

    function get_lpToken() external view returns (address) {
        return address(pair);
    }

    function get_BAMMToken() external view returns (address) {
        return address(iBammErc20);
    }

    function isValidVault(Vault memory vault) external view returns (bool) {
        return _isValidVault(vault);
    }

    function isValidVault(address user) external view returns (bool) {
        return _isValidVault(userVaults[user]);
    }

    function getVault_Rented(address user) external view returns (int256) {
        return userVaults[user].rented;
    }

    function getVault_token0(address user) external view returns (int256) {
        return userVaults[user].token0;
    }

    function getVault_token1(address user) external view returns (int256) {
        return userVaults[user].token1;
    }

    function OZmulDivTest(uint256 a, uint256 b, uint256 c) external pure returns (uint256) {
        return OZMath.mulDiv(a, b, c);
    }

    function OZmulDivRoundingTest(uint256 a, uint256 b, uint256 c) external pure returns (uint256) {
        return OZMath.mulDiv(a, b, c, OZMath.Rounding.Expand);
    }

    function OZsqrtTest(uint256 x) external pure returns (uint256) {
        return OZMath.sqrt(x);
    }

    function FMsqrtTest(uint256 x) external pure returns (uint256) {
        return FraxMath.sqrt(x);
    }

    function FMmulDivRoundingTest(uint256 a, uint256 b, uint256 c) external pure returns (uint256) {
        return FullMath.mulDivRoundingUp(a, b, c);
    }

    function FMmulDivTest(uint256 a, uint256 b, uint256 c) external pure returns (uint256) {
        return FullMath.mulDiv(a, b, c);
    }

    function lpBalance(address a) external view returns (uint256) {
        return pair.balanceOf(a);
    }

    function lpTotalSupply() external view returns (uint256) {
        return pair.totalSupply();
    }

    function BAMMBalance(address a) external view returns (uint256) {
        return iBammErc20.balanceOf(a);
    }

    function BAMMTotalSupply() external view returns (uint256) {
        return iBammErc20.totalSupply();
    }

    function token0Balance(address a) external view returns (uint256) {
        return token0.balanceOf(a);
    }

    function token0TotalSupply() external view returns (uint256) {
        return token0.totalSupply();
    }

    function token1Balance(address a) external view returns (uint256) {
        return token1.balanceOf(a);
    }

    function token1TotalSupply() external view returns (uint256) {
        return token1.totalSupply();
    }

    function get_timeSinceLastInterestPayment() external view returns (uint256) {
        return timeSinceLastInterestPayment;
    }

    function getSqrtBalance() external view returns (uint256) {
        (uint112 reserve0, uint112 reserve1, ) = pair.getReserves();
        uint256 pairTotalSupply = pair.totalSupply();
        pairTotalSupply += _calcMintedSupplyFromPairMintFee(reserve0, reserve1, pairTotalSupply);
        uint256 balance = pair.balanceOf(address(this));
        uint256 sqrtReserve = OZMath.sqrt(uint256(reserve0) * reserve1);
        uint256 sqrtBalance = OZMath.mulDiv(balance, sqrtReserve, pairTotalSupply, OZMath.Rounding.Expand);
        return sqrtBalance;
    }

    function getSqrtReserve() external view returns (uint256) {
        (uint112 reserve0, uint112 reserve1, ) = pair.getReserves();
        uint256 sqrtReserve = OZMath.sqrt(uint256(reserve0) * reserve1);
        return sqrtReserve;
    }

    function getSqrtRentedReal() external view returns (uint256) {
        uint256 sqrtRentedReal = OZMath.mulDiv(
            uint256(sqrtRented),
            rentedMultiplier,
            PRECISION,
            OZMath.Rounding.Expand
        );
        return sqrtRentedReal;
    }

    function syncVault(
        Vault memory _vault,
        int256 _rent,
        uint112 _reserve0,
        uint112 _reserve1,
        uint256 _pairTotalSupply
    ) external returns (int256 lpTokenAmount, int256 token0Amount, int256 token1Amount) {
        return _syncVault(_vault, _rent, _reserve0, _reserve1, _pairTotalSupply);
    }

    function syncVault(
        address user,
        int256 _rent,
        uint112 _reserve0,
        uint112 _reserve1,
        uint256 _pairTotalSupply
    ) external returns (int256 lpTokenAmount, int256 token0Amount, int256 token1Amount) {
        return _syncVault(userVaults[user], _rent, _reserve0, _reserve1, _pairTotalSupply);
    }

    function addToken0(uint256 amount, address to) public nonReentrant returns (Vault memory vault) {
        Action memory action;
        action.token0Amount = toInt256(amount);
        action.to = to;
        return executeActions(action);
    }

    function removeToken0(uint256 amount, address to) public nonReentrant returns (Vault memory vault) {
        Action memory action;
        action.token0Amount = -toInt256(amount);
        action.to = to;
        return executeActions(action);
    }

    function addToken1(uint256 amount, address to) public nonReentrant returns (Vault memory vault) {
        Action memory action;
        action.token1Amount = toInt256(amount);
        action.to = to;
        return executeActions(action);
    }

    function removeToken1(uint256 amount, address to) public nonReentrant returns (Vault memory vault) {
        Action memory action;
        action.token1Amount = -toInt256(amount);
        action.to = to;
        return executeActions(action);
    }

    function borrow(uint256 amount, address to) public nonReentrant returns (Vault memory vault) {
        Action memory action;
        action.rent = toInt256(amount);
        action.to = to;
        return executeActions(action);
    }

    function repay(uint256 amount, address to) public nonReentrant returns (Vault memory vault) {
        Action memory action;
        action.rent = -toInt256(amount);
        action.to = to;
        return executeActions(action);
    }

    function swapToken0(uint256 amount, address to) public nonReentrant returns (Vault memory vault) {
        Action memory action;
        IFraxswapRouterMultihop.FraxswapParams memory swapParams;
        swapParams.recipient = to;
        swapParams.tokenIn = address(token0);
        swapParams.tokenOut = address(token1);
        swapParams.amountIn = amount;
        return executeActionsAndSwap(action, swapParams);
    }

    function swapToken1(uint256 amount, address to) public nonReentrant returns (Vault memory vault) {
        Action memory action;
        IFraxswapRouterMultihop.FraxswapParams memory swapParams;
        swapParams.recipient = to;
        swapParams.tokenIn = address(token1);
        swapParams.tokenOut = address(token0);
        swapParams.amountIn = amount;
        return executeActionsAndSwap(action, swapParams);
    }

    function toInt256(uint256 value) internal pure returns (int256) {
        // Note: Unsafe cast below is okay because `type(int256).max` is guaranteed to be positive
        if (value > uint256(type(int256).max)) {
            revert InsufficientAmount();
        }
        return int256(value);
    }
}
