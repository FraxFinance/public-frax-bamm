// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.19;

// ====================================================================
// |     ______                   _______                             |
// |    / _____________ __  __   / ____(_____  ____ _____  ________   |
// |   / /_  / ___/ __ `| |/_/  / /_  / / __ \/ __ `/ __ \/ ___/ _ \  |
// |  / __/ / /  / /_/ _>  <   / __/ / / / / / /_/ / / / / /__/  __/  |
// | /_/   /_/   \__,_/_/|_|  /_/   /_/_/ /_/\__,_/_/ /_/\___/\___/   |
// |                                                                  |
// ====================================================================
// ========================== BAMMUIHelper ============================
// ====================================================================
// Frax Finance: https://github.com/FraxFinance

import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IFraxswapPair } from "dev-fraxswap/src/contracts/core/interfaces/IFraxswapPair.sol";
import { IFraxswapRouterMultihop } from "dev-fraxswap/src/contracts/periphery/interfaces/IFraxswapRouterMultihop.sol";
// import { FraxMath as Math } from "dev-fraxswap/src/contracts/core/libraries/FraxMath.sol";
import { Math } from "dev-fraxswap/src/contracts/core/libraries/Math.sol";
import { VariableInterestRate } from "src/contracts/VariableInterestRate.sol";
import { BAMM } from "./BAMM.sol";
import { BAMMFactory } from "./factories/BAMMFactory.sol";

contract BAMMUIHelper {
    uint256 constant PRECISION = 1e18;

    struct BAMMState {
        uint256 reserve0;
        uint256 reserve1;
        uint256 totalSupply;
        uint256 rentedMultiplier;
        uint256 sqrtBalance;
        uint256 sqrtRentedReal;
        uint256 utilityRate;
        uint256 ratePerSec;
        uint256 bammTokenTotalSupply;
        uint256 sqrtPerBAMMToken;
        uint256 sqrtPerLPToken;
        uint256 token0PerSqrt;
        uint256 token1PerSqrt;
    }

    function getBAMMState(BAMM bamm) public returns (BAMMState memory state) {
        (state.reserve0, state.reserve1, state.totalSupply, state.rentedMultiplier) = bamm.addInterest();
        if (state.totalSupply > 0) {
            uint256 balance = bamm.pair().balanceOf(address(bamm));
            state.sqrtBalance = Math.sqrt(
                ((balance * state.reserve0) / state.totalSupply) * ((balance * state.reserve1) / state.totalSupply)
            );
            state.sqrtRentedReal = (uint256(bamm.sqrtRented()) * state.rentedMultiplier) / PRECISION;
            if (state.sqrtRentedReal > 0) {
                state.utilityRate = (state.sqrtRentedReal * PRECISION) / (state.sqrtBalance + state.sqrtRentedReal);
            }
            uint256 utilScaled = (state.utilityRate * 1e5) / bamm.MAX_UTILITY_RATE();
            uint256 period = block.timestamp - bamm.timeSinceLastInterestPayment();
            (state.ratePerSec, ) = VariableInterestRate(address(bamm.variableInterestRate())).getNewRate(
                period,
                utilScaled,
                uint64(bamm.fullUtilizationRate())
            );
            state.bammTokenTotalSupply = bamm.iBammErc20().totalSupply();
            if (state.bammTokenTotalSupply > 0) {
                state.sqrtPerBAMMToken =
                    ((state.sqrtBalance + state.sqrtRentedReal) * PRECISION) /
                    state.bammTokenTotalSupply;
            }
            uint256 _sqrtK = Math.sqrt(state.reserve0 * state.reserve1);
            state.sqrtPerLPToken = (_sqrtK * PRECISION) / state.totalSupply;
            state.token0PerSqrt = (state.reserve0 * PRECISION) / _sqrtK;
            state.token1PerSqrt = (state.reserve1 * PRECISION) / _sqrtK;
        }
    }

    struct BAMMVault {
        int256 token0;
        int256 token1;
        int256 rented;
        uint256 rentedReal;
        int256 rentedToken0;
        int256 rentedToken1;
        uint256 ltv;
        int256 value0;
        int256 value1;
        int256 leverage0;
        int256 leverage1;
        bool solvent;
        bool solventAfterAction;
    }

    function getVaultState(BAMM bamm, address user) public returns (BAMMVault memory vault) {
        (int256 token0, int256 token1, int256 rented) = bamm.userVaults(user);
        return getVaultState(bamm, token0, token1, rented);
    }

    function getVaultState(
        BAMM bamm,
        int256 token0,
        int256 token1,
        int256 rented
    ) public returns (BAMMVault memory vault) {
        (uint256 reserve0, uint256 reserve1, , uint256 rentedMultiplier) = bamm.addInterest();
        vault.token0 = token0;
        vault.token1 = token1;
        vault.rented = rented;
        vault.rentedReal = (uint256(vault.rented) * rentedMultiplier) / PRECISION;
        uint256 sqrtK = Math.sqrt(reserve0 * reserve1);
        if (sqrtK > 0) {
            vault.rentedToken0 = int256((reserve0 * vault.rentedReal) / sqrtK);
            vault.rentedToken1 = int256((reserve1 * vault.rentedReal) / sqrtK);
        }
        vault.value0 = (token0 + (token1 * int256(reserve0)) / int256(reserve1) - 2 * int256(vault.rentedToken0));
        vault.value1 = (token1 + (token0 * int256(reserve1)) / int256(reserve0) - 2 * int256(vault.rentedToken1));
        if (vault.token0 > 0 && vault.token1 > 0) {
            vault.ltv =
                (uint256(vault.rented) * rentedMultiplier) /
                Math.sqrt(uint256(vault.token0) * uint256(vault.token1));
            vault.leverage0 = ((token0 - int256(vault.rentedToken0)) * 1e18) / vault.value0;
            vault.leverage1 = ((token1 - int256(vault.rentedToken1)) * 1e18) / vault.value1;
        }
        vault.solvent = vault.rented == 0 || vault.ltv < bamm.SOLVENCY_THRESHOLD_LIQUIDATION();
        vault.solventAfterAction = vault.rented == 0 || vault.ltv < bamm.SOLVENCY_THRESHOLD_LIQUIDATION();
    }

    function calcZap(
        BAMM bamm,
        int256 token0,
        int256 token1,
        int256 rented,
        int256 targetLTV,
        int256 targetVaultRatio
    ) external returns (int256 rent, int256 swap) {
        CalcZapData memory d;
        (d.reserve0, d.reserve1, d.pairTotalSupply, d.rentedMultiplier) = bamm.addInterest();
        d.fee = bamm.pair().fee();
        d.sqrtK = int256(Math.sqrt(d.reserve0 * d.reserve1));
        int256 target0 = 1e18;
        int256 target1 = int256((uint256(targetVaultRatio) * d.reserve1) / d.reserve0);
        int256 targetRent = (targetLTV * int256(Math.sqrt(uint256(target0 * target1)))) / 1e18;
        int256 targetValue = target0 +
            int256((uint256(target1) * d.reserve0) / d.reserve1) -
            (2 * targetRent * int256(d.reserve0)) /
            d.sqrtK;
        for (uint256 i = 0; i < 20; ++i) {
            d.rentedReal = (rented * int256(d.rentedMultiplier)) / 1e18 + rent;
            d.resultToken0 = token0;
            d.resultToken1 = token1;
            if (rent > 0) {
                d.resultToken0 += (rent * int256(d.reserve0)) / d.sqrtK;
                d.resultToken1 += (rent * int256(d.reserve1)) / d.sqrtK;
            }
            if (swap < 0) {
                // swap token0 for token1
                d.resultToken0 += swap;
                d.resultToken1 += int256(getAmountOut(d.reserve0, d.reserve1, d.fee, uint256(-swap)));
            } else if (swap > 0) {
                // swap token1 for token0
                d.resultToken0 += swap;
                d.resultToken1 -= int256(getAmountIn(d.reserve1, d.reserve0, d.fee, uint256(swap)));
            }
            if (rent < 0) {
                int256 newReserve0 = int256(d.reserve0) + token0 - d.resultToken0;
                int256 newReserve1 = int256(d.reserve1) + token1 - d.resultToken1;
                int256 newSqrt = int256(Math.sqrt(uint256(newReserve0 * newReserve1)));
                d.resultToken0 += (rent * newReserve0) / newSqrt;
                d.resultToken1 += (rent * newReserve1) / newSqrt;
            }
            d.value =
                d.resultToken0 +
                (d.resultToken1 * int256(d.reserve0)) /
                int256(d.reserve1) -
                (2 * d.rentedReal * int256(d.reserve0)) /
                d.sqrtK;
            if (i % 2 == 0) rent = rent + ((targetRent * d.value) / targetValue) - d.rentedReal;
            else swap = swap + ((target0 * d.value) / targetValue) - d.resultToken0;
        }
    }

    function calcRentForLTV(int256 token0, int256 token1, int256 targetLTV) public pure returns (int256 rent) {
        // Solve rent*PRECISION/sqrt((token0+rent)*(token1+rent))=targetLTV;
        int256 PREC = 1e18;
        rent =
            (targetLTV *
                int256(
                    Math.sqrt(
                        uint256(
                            targetLTV *
                                targetLTV *
                                (token0 + token1) *
                                (token0 + token1) -
                                4 *
                                token0 *
                                token1 *
                                (targetLTV * targetLTV - PREC * PREC)
                        )
                    )
                ) -
                targetLTV *
                targetLTV *
                (token0 + token1)) /
            (2 * (targetLTV * targetLTV - PREC * PREC));
    }

    function calcRentForLTV(
        BAMM bamm,
        int256 token0,
        int256 token1,
        int256 rented,
        int256 targetLTV
    ) public returns (int256 rent) {
        BAMMState memory state = getBAMMState(bamm);
        BAMMVault memory vault = getVaultState(bamm, token0, token1, rented);
        int256 netToken0 = vault.token0 - int256(vault.rentedToken0);
        int256 netToken1 = vault.token1 - int256(vault.rentedToken1);
        int256 sqrtK = int256(Math.sqrt(state.reserve0 * state.reserve1));
        if (netToken0 < 0) {
            rent =
                (((netToken1 * sqrtK) / int256(state.reserve1)) *
                    calcRentForLTV(
                        1e18,
                        (1e18 * ((netToken0 * int256(state.reserve1)) / int256(state.reserve0))) / netToken1,
                        targetLTV
                    )) /
                1e18;
        } else if (netToken1 < 0) {
            rent =
                (((netToken0 * sqrtK) / int256(state.reserve0)) *
                    calcRentForLTV(
                        1e18,
                        (1e18 * ((netToken1 * int256(state.reserve0)) / int256(state.reserve1))) / netToken0,
                        targetLTV
                    )) /
                1e18;
        }
    }

    uint256 public constant MAX_WITHDRAW_BORROW_LTV = 0.66666666666666666e18;
    int256 public constant MAX_WITHDRAW_BAMM_LTV = 0.97999e18;
    uint256 public constant TARGET_UTILITY_RATE = 0.949999e18;

    function getMaxWithdraw(
        BAMM bamm,
        int256 token0,
        int256 token1,
        int256 rented
    ) public returns (int256 maxWithdrawToken0, int256 maxWithdrawToken1) {
        BAMMState memory state = getBAMMState(bamm);
        int256 rentedReal = (rented * int256(state.rentedMultiplier)) / 1e18;
        int256 netToken0 = token0 -
            (int256(state.reserve0) * rentedReal) /
            int256(Math.sqrt(state.reserve0 * state.reserve1));
        int256 netToken1 = token1 -
            (int256(state.reserve1) * rentedReal) /
            int256(Math.sqrt(state.reserve0 * state.reserve1));
        {
            int256 minToken0;
            if (netToken1 > 0) {
                minToken0 = -int256(
                    (((uint256(netToken1) * MAX_WITHDRAW_BORROW_LTV) / 1e18) * state.reserve0) / state.reserve1
                );
            } else if (netToken0 > 0) {
                minToken0 = int256(
                    (((uint256(-netToken1) * 1e18) / MAX_WITHDRAW_BORROW_LTV) * state.reserve0) / state.reserve1
                );
            }
            int256 rent = calcRentForLTV(bamm, minToken0, netToken1, 0, MAX_WITHDRAW_BAMM_LTV);
            int256 maxRentReal = int256(
                (TARGET_UTILITY_RATE * (state.sqrtRentedReal + state.sqrtBalance)) / 1e18 - state.sqrtRentedReal
            );
            if (rent > maxRentReal + rentedReal) {
                rent = maxRentReal + rentedReal;
                int256 token0Rented = (rent * int256(state.reserve0)) /
                    int256(Math.sqrt(state.reserve0 * state.reserve1));
                int256 token1AfterRent = netToken1 +
                    (rent * int256(state.reserve1)) /
                    int256(Math.sqrt(state.reserve0 * state.reserve1));
                if (rent ** 2 < (type(int256).max / 1e18)) {
                    minToken0 =
                        int256(
                            (((uint256(rent) * uint256(rent) * 1e18) / uint256(MAX_WITHDRAW_BAMM_LTV)) * 1e18) /
                                uint256(MAX_WITHDRAW_BAMM_LTV)
                        ) /
                        token1AfterRent -
                        token0Rented;
                } else {
                    minToken0 = netToken0;
                }
            }
            maxWithdrawToken0 = minToken0 - netToken0;
        }
        {
            int256 minToken1;
            if (netToken0 > 0) {
                minToken1 = -int256(
                    (((uint256(netToken0) * MAX_WITHDRAW_BORROW_LTV) / 1e18) * state.reserve1) / state.reserve0
                );
            } else if (netToken1 > 0) {
                minToken1 = int256(
                    (((uint256(-netToken0) * 1e18) / MAX_WITHDRAW_BORROW_LTV) * state.reserve1) / state.reserve0
                );
            }
            int256 rent = calcRentForLTV(bamm, netToken0, minToken1, 0, MAX_WITHDRAW_BAMM_LTV);
            int256 maxRentReal = int256(
                (TARGET_UTILITY_RATE * (state.sqrtRentedReal + state.sqrtBalance)) / 1e18 - state.sqrtRentedReal
            );
            if (rent > maxRentReal + rentedReal) {
                rent = maxRentReal + rentedReal;
                int256 token1Rented = (rent * int256(state.reserve1)) /
                    int256(Math.sqrt(state.reserve0 * state.reserve1));
                int256 token0AfterRent = netToken0 +
                    (rent * int256(state.reserve0)) /
                    int256(Math.sqrt(state.reserve0 * state.reserve1));
                if (rent ** 2 < (type(int256).max / 1e18)) {
                    minToken1 =
                        int256(
                            (((uint256(rent) * uint256(rent) * 1e18) / uint256(MAX_WITHDRAW_BAMM_LTV)) * 1e18) /
                                uint256(MAX_WITHDRAW_BAMM_LTV)
                        ) /
                        token0AfterRent -
                        token1Rented;
                } else {
                    minToken1 = netToken1;
                }
            }
            maxWithdrawToken1 = minToken1 - netToken1;
        }
    }

    struct ChartPoint {
        int256 price;
        int256 value;
        int256 blValue; // Value when using regular B&L.
        int256 rentedToken0;
        int256 rentedToken1;
    }

    // Price of token1 in token0, value of the vault in token0
    function getChartData0(BAMM bamm, address user) external returns (ChartPoint[1000] memory points) {
        BAMMState memory state = getBAMMState(bamm);
        BAMMVault memory vault = getVaultState(bamm, user);
        int256 currentPrice = int256((state.reserve0 * 1e18) / state.reserve1);
        int256 price = 1e18 / 1000;
        uint256 sqrtK = Math.sqrt(state.reserve0 * state.reserve1);
        for (uint256 i = 0; i < 1000; ++i) {
            points[i].price = (currentPrice * price) / 1e18;
            uint256 newReserve0 = (state.reserve0 * Math.sqrt(uint256(price * 1e18))) / 1e18;
            uint256 newReserve1 = (state.reserve1 * 1e18) / Math.sqrt(uint256(price * 1e18));
            int256 rentedToken0 = int256((newReserve0 * vault.rentedReal) / sqrtK);
            int256 rentedToken1 = int256((newReserve1 * vault.rentedReal) / sqrtK);
            points[i].value =
                vault.token0 -
                rentedToken0 +
                ((vault.token1 - rentedToken1) * int256(newReserve0)) /
                int256(newReserve1);
            points[i].blValue =
                vault.token0 -
                vault.rentedToken0 +
                ((vault.token1 - vault.rentedToken1) * int256(newReserve0)) /
                int256(newReserve1);
            if (points[i].blValue < 0) points[i].blValue = 0;
            price = (price * 1_008_046_583) / 1_000_000_000; // 3000^(1/999)
            points[i].rentedToken0 = rentedToken0;
            points[i].rentedToken1 = rentedToken1;
        }
    }

    // Price of token0 in token1, value of the vault in token1
    function getChartData1(BAMM bamm, address user) external returns (ChartPoint[1000] memory points) {
        BAMMState memory state = getBAMMState(bamm);
        BAMMVault memory vault = getVaultState(bamm, user);
        int256 currentPrice = int256((state.reserve1 * 1e18) / state.reserve0);
        int256 price = 1e18 / 1000;
        uint256 sqrtK = Math.sqrt(state.reserve0 * state.reserve1);
        for (uint256 i = 0; i < 1000; ++i) {
            points[i].price = (currentPrice * price) / 1e18;
            uint256 newReserve0 = (state.reserve0 * 1e18) / Math.sqrt(uint256(price * 1e18));
            uint256 newReserve1 = (state.reserve1 * Math.sqrt(uint256(price * 1e18))) / 1e18;
            int256 rentedToken0 = int256((newReserve0 * vault.rentedReal) / sqrtK);
            int256 rentedToken1 = int256((newReserve1 * vault.rentedReal) / sqrtK);
            points[i].value =
                vault.token1 -
                rentedToken1 +
                ((vault.token0 - rentedToken0) * int256(newReserve1)) /
                int256(newReserve0);
            points[i].blValue =
                vault.token1 -
                vault.rentedToken1 +
                ((vault.token0 - vault.rentedToken0) * int256(newReserve1)) /
                int256(newReserve0);
            if (points[i].blValue < 0) points[i].blValue = 0;
            price = (price * 1_008_046_583) / 1_000_000_000; // 3000^(1/999)
            points[i].rentedToken0 = rentedToken0;
            points[i].rentedToken1 = rentedToken1;
        }
    }

    struct CalcZapData {
        uint256 reserve0;
        uint256 reserve1;
        uint256 pairTotalSupply;
        uint256 rentedMultiplier;
        uint256 fee;
        int256 sqrtK;
        int256 rentedReal;
        int256 resultToken0;
        int256 resultToken1;
        int256 value;
    }

    // given an input amount of an asset and pair reserves, returns the maximum output amount of the other asset
    function getAmountOut(
        uint256 reserveIn,
        uint256 reserveOut,
        uint256 fee,
        uint256 amountIn
    ) internal pure returns (uint256) {
        uint256 amountInWithFee = amountIn * fee;
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = (reserveIn * 10_000) + amountInWithFee;
        return numerator / denominator;
    }

    // given an output amount of an asset and pair reserves, returns a required input amount of the other asset
    function getAmountIn(
        uint256 reserveIn,
        uint256 reserveOut,
        uint256 fee,
        uint256 amountOut
    ) internal pure returns (uint256) {
        uint256 numerator = reserveIn * amountOut * 10_000;
        uint256 denominator = (reserveOut - amountOut) * fee;
        return (numerator / denominator) + 1;
    }

    /// @notice Given a token you want to borrow, how much rent do you need.
    /// @notice Modifies state because the TWAMMs and interest need to be synced.
    /// @param token Address of the token you want to borrow
    /// @param amountOutDesired How much of the token you want to borrow
    /// @return rent The value of "rent" you should use in executeActions's Action
    /// @return lpUnwound Informational: the amount of BAMM LP that was unwound to release your desired token
    /// @return amountOutOtherToken How much of the other token was also released in the LP unwinding.
    /// You can swap it out for even more of your desired token if you want with executeActionsAndSwap's swapParams
    function calcRent(
        BAMM bamm,
        address token,
        uint256 amountOutDesired
    ) external returns (int256 rent, uint256 lpUnwound, uint256 amountOutOtherToken) {
        // Sync the LP, then add the interest
        (uint256 reserve0, uint256 reserve1, uint256 pairTotalSupply, uint256 rentedMultiplier) = bamm.addInterest();
        // Get the price (in terms of the other token) of your desired token
        {
            uint256 reserveDesired;
            uint256 reserveOther;
            if (token == address(bamm.token0())) {
                reserveDesired = reserve0;
                reserveOther = reserve1;
            } else if (token == address(bamm.token1())) {
                reserveDesired = reserve1;
                reserveOther = reserve0;
            } else {
                revert InvalidToken();
            }

            // Calculate the amount of the other token, as well as the LP
            // Use substitution to avoid rounding errors
            lpUnwound = (amountOutDesired * pairTotalSupply) / reserveDesired;
            if ((lpUnwound * reserveDesired) / pairTotalSupply < amountOutDesired) lpUnwound += 1;
            amountOutOtherToken = (lpUnwound * reserveOther) / pairTotalSupply;
        }
        uint256 sqrtAmountRented = (Math.sqrt(uint256(reserve0) * reserve1) * lpUnwound) / pairTotalSupply;
        if ((sqrtAmountRented * pairTotalSupply) / Math.sqrt(uint256(reserve0) * reserve1) < lpUnwound) {
            sqrtAmountRented += 1;
        }
        uint256 rentedMultiplier_ = rentedMultiplier; // gas
        rent = int256((sqrtAmountRented * 1e18) / rentedMultiplier_);
        if ((uint256(rent) * rentedMultiplier_) / 1e18 < sqrtAmountRented) rent += 1;
    }

    /// @notice public view function to view the calculated interest rate at a given utilization
    /// @dev see: https://github.com/FraxFinance/dev-fraxswap/blob/9744c757f7e51c1deee3f5db50d3aaec495aea01/src/contracts/core/FraxswapPair.sol#L317
    /// @param reserve0 The reserves for token0 of the pair
    /// @param reserve1 The reserves for token1 of the pair
    /// @return tsAdjustment The total supply adjustment of the lp token due to fees
    function _calcMintedSupplyFromPairMintFee(
        BAMM bamm,
        uint256 reserve0,
        uint256 reserve1,
        uint256 totalSupply
    ) internal view returns (uint256 tsAdjustment) {
        uint256 k = Math.sqrt(uint256(reserve0) * reserve1);
        IFraxswapPair pair = bamm.pair();
        uint256 kLast = pair.kLast();
        if (kLast != 0) {
            kLast = Math.sqrt(kLast);
            if (k > kLast) {
                uint256 num = totalSupply * (k - kLast);
                uint256 denom = (k * 5) + kLast;
                tsAdjustment = num / denom;
            }
        }
    }

    struct TVLInfo {
        address token0;
        address token1;
        uint256 tvlInToken0;
        uint256 tvlInToken1;
    }

    function getTVL(BAMM bamm) public view returns (TVLInfo memory tvl) {
        IFraxswapPair pair = bamm.pair();
        uint256 pairTotalSupply = pair.totalSupply();
        uint256 pairInBAMM = pair.balanceOf(address(bamm));
        (uint112 reserve0, uint112 reserve1, ) = pair.getReserves();
        uint256 tvlToken0 = (reserve0 * pairInBAMM) / pairTotalSupply + bamm.token0().balanceOf(address(bamm));
        uint256 tvlToken1 = (reserve1 * pairInBAMM) / pairTotalSupply + bamm.token1().balanceOf(address(bamm));
        uint256 tvlInToken0 = tvlToken0 + (tvlToken1 * reserve0) / reserve1;
        uint256 tvlInToken1 = tvlToken1 + (tvlToken0 * reserve1) / reserve0;
        tvl = TVLInfo({
            token0: address(bamm.token0()),
            token1: address(bamm.token1()),
            tvlInToken0: tvlInToken0,
            tvlInToken1: tvlInToken1
        });
    }

    function getMultiTVL(address[] memory bamms) public view returns (TVLInfo[] memory tvls) {
        tvls = new TVLInfo[](bamms.length);
        for (uint256 i = 0; i < bamms.length; ++i) {
            tvls[i] = getTVL(BAMM(bamms[i]));
        }
    }

    function getAllTVL(BAMMFactory factory) public view returns (TVLInfo[] memory tvls) {
        return getMultiTVL(factory.bammsArray());
    }

    function fraxswapFeesEarned(IFraxswapPair pair) public view returns (uint256) {
        (uint112 reserve0, uint112 reserve1, ) = pair.getReserves();
        uint256 pairTotalSupply = pair.totalSupply();
        return ((Math.sqrt(uint256(reserve0) * reserve1) - pairTotalSupply) * 1E18) / pairTotalSupply;
    }

    function fraxswapFeesEarnedMulti(IFraxswapPair[] memory pairs) public view returns (uint256[] memory fees) {
        fees = new uint256[](pairs.length);
        for (uint256 i = 0; i < pairs.length; ++i) {
            fees[i] = fraxswapFeesEarned(pairs[i]);
        }
    }

    error InvalidToken();
}
