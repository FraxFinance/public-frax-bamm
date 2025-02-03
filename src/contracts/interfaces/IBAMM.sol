pragma solidity ^0.8.0;

import { IERC20Metadata as IERC20 } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import { IFraxswapPair } from "dev-fraxswap/src/contracts/core/interfaces/IFraxswapPair.sol";
import { IFraxswapFactory } from "dev-fraxswap/src/contracts/core/interfaces/IFraxswapFactory.sol";
import { IFraxswapRouterMultihop } from "dev-fraxswap/src/contracts/periphery/interfaces/IFraxswapRouterMultihop.sol";

import { BAMMERC20 } from "src/contracts/BAMMERC20.sol";
import { IFraxswapOracle } from "src/contracts/interfaces/IFraxswapOracle.sol";
import { IBAMMFactory } from "src/contracts/interfaces/IBAMMFactory.sol";
import { IVariableInterestRate } from "src/contracts/interfaces/IVariableInterestRate.sol";

interface IBAMM {
    // #####################################
    // ############## Errors ###############
    // #####################################

    error CannotWithdrawToSelf();
    error InsufficientAmount();
    error ZeroLiquidityMinted();
    error NotSolvent();
    error Solvent();
    error IncorrectSwapTokens();
    error InvalidVault();
    error InvalidUtilityRate();
    error OraclePriceDeviated();
    error IncorrectAmountOutMinimum();
    error InvalidRent();
    error NotFactory();
    error NoBAMMTokensMinted();

    // #####################################
    // ############## Structs ##############
    // #####################################

    /// @notice Details for a user's vault
    struct Vault {
        int256 token0; // Token 0 in the LP
        int256 token1; // Token 1 in the LP
        int256 rented; // SQRT(#token0 * #token1) that is rented
    }

    /// @notice Function parameter pack for various actions. Different parts may be empty for different actions.
    struct Action {
        int256 token0Amount; // Amount of token 0. Positive = add to vault. Negative = remove from vault
        int256 token1Amount; // Amount of token 1. Positive = add to vault. Negative = remove from vault
        int256 rent; // SQRT(#token0 * #token1). Positive if borrowing, negative if repaying
        address to; // A destination address
        uint256 token0AmountMin; // Minimum amount of token 0 expected
        uint256 token1AmountMin; // Minimum amount of token 1 expected
        bool closePosition; // Whether to close the position or not
        bool approveMax; // Whether to approve max (e.g. uint256(-1) or similar)
        uint8 v; // Part of a signature
        bytes32 r; // Part of a signature
        bytes32 s; // Part of a signature
        uint256 deadline; // Deadline of this action
    }

    // #####################################
    // ######### State variables ###########
    // #####################################

    function iBammErc20() external view returns (BAMMERC20);
    function token0() external view returns (IERC20);
    function token1() external view returns (IERC20);
    function pair() external view returns (IFraxswapPair);
    function routerMultihop() external view returns (IFraxswapRouterMultihop);
    function fraxswapOracle() external view returns (IFraxswapOracle);
    function factory() external view returns (address);
    function sqrtRented() external view returns (int256);
    function rentedMultiplier() external view returns (uint256);
    function timeSinceLastInterestPayment() external view returns (uint256);
    function fullUtilizationRate() external view returns (uint256);
    function variableInterestRate() external view returns (IVariableInterestRate);
    function getUserVault(address user) external view returns (Vault memory vault);

    // #####################################
    // ############ Functions ##############
    // #####################################

    function version() external pure returns (uint256 major, uint256 minor, uint256 patch);
    function mint(address to, uint256 lpIn) external returns (uint256 bammOut);
    function redeem(address to, uint256 bammIn) external returns (uint256 lpOut);
    function executeActions(Action memory action) external returns (Vault memory vault);
    function executeActionsAndSwap(
        Action memory action,
        IFraxswapRouterMultihop.FraxswapParams memory swapParams
    ) external returns (Vault memory vault);
    function microLiquidate(address user) external returns (uint256 token0Fee, uint256 token1Fee);
    function addInterest()
        external
        returns (uint256 reserve0, uint256 reserve1, uint256 totalSupply, uint256 _rentedMultiplier);
    function previewInterestRate(uint256 _utilization) external view returns (uint256 newRatePerSec);

    // ####################################
    // ############## Events ##############
    // ####################################

    /// @notice Emitted when BAMM state changes
    /// @param sqrtRentedReal rented sqrt amount
    /// @param sqrtBalance sqrt of the LP tokens held
    /// @param rentedMultiplier multiplier that increases with interest
    /// @param interestRate current interest rate
    event BAMMState(uint256 sqrtRentedReal, uint256 sqrtBalance, uint256 rentedMultiplier, uint256 interestRate);

    /// @notice Emitted when BAMM tokens get minted by a user directly
    /// @param lender The person lending the LP
    /// @param recipient The recipient of the minted BAMM tokens
    /// @param lpIn The amount of LP being sent in
    /// @param bammOut The amount of BAMM tokens minted
    event BAMMMinted(address indexed lender, address indexed recipient, uint256 lpIn, uint256 bammOut);

    /// @notice Emitted when BAMM tokens get redeemed by a user directly
    /// @param lender The person redeeming the BAMM tokens
    /// @param recipient The recipient of the LP tokens
    /// @param bammIn The amount of BAMM tokens being sent in
    /// @param lpOut The amount of LP sent out
    event BAMMRedeemed(address indexed lender, address indexed recipient, uint256 bammIn, uint256 lpOut);

    /// @notice Emitted when a vault is updated
    /// @param user The address of the user
    /// @param token0 The amount of token0 in the vault
    /// @param token1 The amount of token1 in the vault
    event VaultUpdated(address indexed user, int256 token0, int256 token1, int256 rent);

    /// @notice Emitted a users executes a vault action
    /// @param user The address of the user
    /// @param token0 token0 changed (positive is tokens added, negative is tokens withdrawn)
    /// @param token1 token1 changed (positive is tokens added, negative is tokens withdrawn)
    /// @param rent Rent changed (positive is renting, negative is paying back)
    event ExecuteAction(address indexed user, int256 token0, int256 token1, int256 rent);

    /// @notice Emitted a users vault changes
    /// @param user The address of the user
    /// @param token0 token0 swapped (positive is in, negative is out)
    /// @param token1 token1 swapped (positive is in, negative is out)
    event VaultSwap(address indexed user, int256 token0, int256 token1);

    /// @notice Emitted when a user pays back the rented LP
    /// @param user The user
    /// @param rent The rent change
    /// @param token0ToAddToLp Token0 paid back
    /// @param token1ToAddToLp Token1 paid back
    /// @param closePosition Whether the position was closed or not
    event RentRepaid(
        address indexed user,
        int256 rent,
        uint256 token0ToAddToLp,
        uint256 token1ToAddToLp,
        bool closePosition
    );

    /// @notice Emitted when a user starts renting
    /// @param user The user
    /// @param rent The rent change
    /// @param token0Amount Token0 credited to borrower's vault
    /// @param token1Amount Token1 credited to borrower's vault
    event Renting(address indexed user, int256 rent, int256 token0Amount, int256 token1Amount);

    /// @notice Emitted when a user gets micro liquidated
    /// @param user The user being liquidated
    /// @param liquidator The person doing the liquidating
    /// @param token0Fee Amount of liquidation fee in token0 paid
    /// @param token1Fee Amount of liquidation fee in token1 paid
    event MicroLiquidate(address indexed user, address indexed liquidator, uint256 token0Fee, uint256 token1Fee);

    /// @notice Emitted when a the interest rate contract is updated
    /// @param previousVariableInterestRate The previous interest rate contract
    /// @param newVariableInterestRate The new interest rate contract
    event NewVariableInterestRate(
        address indexed previousVariableInterestRate,
        address indexed newVariableInterestRate
    );

    /// @notice Emitted when a new `maxOracleDiff` is set
    /// @param oldMaxOracleDiff The old `maxOracleDiff`
    /// @param newMaxOracleDiff The new `maxOracleDiff`
    event NewMaxOracleDiff(uint256 oldMaxOracleDiff, uint256 newMaxOracleDiff);
}
