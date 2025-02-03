// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

// ====================================================================
// |     ______                   _______                             |
// |    / _____________ __  __   / ____(_____  ____ _____  ________   |
// |   / /_  / ___/ __ `| |/_/  / /_  / / __ \/ __ `/ __ \/ ___/ _ \  |
// |  / __/ / /  / /_/ _>  <   / __/ / / / / / /_/ / / / / /__/  __/  |
// | /_/   /_/   \__,_/_/|_|  /_/   /_/_/ /_/\__,_/_/ /_/\___/\___/   |
// |                                                                  |
// ====================================================================
// =============================== BAMM ===============================
// ====================================================================
/*
 ** BAMM (Borrow AMM)
 ** - The BAMM wraps Uniswap/Fraxswap like LP tokens (#token0 * #token1 = K), giving out an ERC-20 wrapper token in return
 ** - Users have a personal vault where they can add / remove token0 and token1.
 ** - Users can rent the LP constituent token0s and token1s, the liquidity from which will be removed and stored in the users vault.
 ** - Rented LP constituent token0s and token1s are accounted as SQRT(#token0 * #token1)
 ** - The user can remove tokens from their personal vault as long as the SQRT(#token0 * #token1) is more than the rented value
 ** - Borrowers pay an interest rate based on the utility factor
 ** - Borrowers can only be liquidated due to interest rate payments, not due to price movements.
 ** - Liquidations will be auctioned, to be small and cheap
 ** - No price oracle needed!
 */

/*
   -----------------------------------------------------------
   -------------------- EXAMPLE SCENARIOS --------------------
   -----------------------------------------------------------

   Assume Fraxswap FRAX/FXS LP @ 0x03B59Bd1c8B9F6C265bA0c3421923B93f15036Fa.
   token0 = FXS, token1 = FRAX

   Scenario 1: User wants to rent some FXS using FRAX as collateral
   ===================================
   1) User obtains some FRAX, which will be used as collateral
   2) User calls executeActionsAndSwap() with 
      a) Positive token1Amount (add FRAX to vault)
      b) Negative token0Amount (withdraw FXS from vault)
      c) Positive rent (renting)
      d) The swapParams to swap SOME of the excess FRAX for FXS (they need to remain solvent at the end of the day)
      e) (Optional) v,r,s for a permit (token1 to this contract) for the vault add
   3) The internal call flow will be:
      i) BAMM-owned LP is unwound into BOTH FRAX and FXS, according to the supplied rent parameter. Both tokens are added to the user's vault.
      ii) User supplied FRAX is added to their vault to increase their collateral
      iii) Some of the excess FRAX from the LP unwind is swapped for FXS (according to swapParams)
      iv) FXS is sent to the user
      v) Contract will revert if the user is insolvent or the LP utility is above MAX_UTILITY_RATE


   Scenario 2: User from Scenario 1 wants to repay SOME of their rented FXS and get SOME FRAX back
   ===================================
   1) User calls executeActionsAndSwap() with 
      a) Negative token1Amount (withdraw FRAX from vault)
      b) Positive token0Amount (add FXS to vault)
      c) Negative rent (repaying)
      d) token0AmountMin to prevent sandwiches from the LP add
      e) token1AmountMin to prevent sandwiches from the LP add
      f) The swapParams to swap SOME of the FXS for FRAX. LP will be added at the current ratio so this is helpful.
      g) (Optional) v,r,s for a permit (token0 to this contract) for the vault add
   2) The internal call flow will be:
      i) Interest accrues so the user owes a little bit more FXS (and/or FRAX) now.
      ii) User-supplied FXS is added to the vault
      iii) Some of the FXS is swapped for FRAX (according to swapParams). 
      iv) FRAX and FXS are added (at current LP ratio) to make the Fraxswap LP, which becomes BAMM-owned, according to the supplied rent parameter.
      v) Accounting updated to lower rent and vaulted tokens.
      vi) FRAX is sent to the user
      vii) Contract will revert if the user is insolvent or the LP utility is above MAX_UTILITY_RATE


   Scenario 3: User from Scenario 1 wants to repay the remaining rented FXS, get their FRAX back, and close the position
   ===================================
   1) User calls executeActionsAndSwap() with 
      a) Negative token1Amount (withdraw FRAX from vault)
      b) Positive token0Amount (add FXS to vault)
      c) closePosition as true. No need to supply rent as the function will override it anyways 
      d) token0AmountMin to prevent sandwiches from the LP add
      e) token1AmountMin to prevent sandwiches from the LP add
      f) The swapParams to swap SOME of the FXS for FRAX. LP will be added at the current ratio so this is helpful.
      g) (Optional) v,r,s for a permit (token0 to this contract) for the vault add
   2) The internal call flow will be:
      i) Interest accrues so the user owes a little bit more FXS (and/or FRAX) now.
      ii) User-supplied FXS is added to the vault
      iii) Some of the FXS is swapped for FRAX (according to swapParams). 
      iv) Accounting updated to lower rent and vaulted tokens. 
      v) Any remaining FRAX or FXS needed is safeTransferFrom'd the user
      vi) FRAX and FXS are added (at current LP ratio) to make the Fraxswap LP, which becomes BAMM-owned, according to the supplied rent parameter
      vii) FRAX is sent back to the user
      viii) Contract will revert if the user is insolvent or the LP utility is above MAX_UTILITY_RATE


   Scenario 4: User wants to loan some LP and earn interest
   ===================================
   1) Approve LP to this BAMM contract
   2) Call mint(), which will give you BAMM tokens as a "receipt"
   3) Wait some time, and assume some other people borrow. Interest accrues
   4) Call redeem(), which burns your BAMM tokens and gives you your LP back, plus some extra LP as interest.
 
*/

// Frax Finance: https://github.com/FraxFinance

import { IERC20Permit } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { Math } from "dev-fraxswap/src/contracts/core/libraries/Math.sol";

import "src/contracts/interfaces/IBAMM.sol";

contract BAMM is IBAMM, ReentrancyGuard {
    using SafeCast for *;
    using Strings for uint256;

    // ############################################
    // ############## STATE VARIABLES #############
    // ############################################

    BAMMERC20 public immutable iBammErc20;

    /// @notice Token 0 in the Fraxswap LP
    IERC20 public immutable token0;

    /// @notice Token 1 in the Fraxswap LP
    IERC20 public immutable token1;

    /// @notice Address of the Fraxswap pair
    IFraxswapPair public immutable pair;

    /// @notice Address of the Fraxswap factory
    IFraxswapFactory public immutable pairFactory;

    /// @notice The Fraxswap router
    IFraxswapRouterMultihop public immutable routerMultihop;

    /// @notice Price oracle for the Fraxswap pair
    IFraxswapOracle public immutable fraxswapOracle;

    /// @notice Address of the BAMMFactory to create this contract
    address public immutable factory;

    /// @notice The variableInterestRate associated
    IVariableInterestRate public variableInterestRate;

    /// @notice Tracks the amount of rented liquidity
    /// @dev Will never be < 0
    int256 public sqrtRented;

    /// @notice Multiplier used in interest rate and rent amount calculations. Never decreases and acts like an accumulator of sorts.
    uint256 public rentedMultiplier = PRECISION; // Initialized at PRECISION, but will change

    /// @notice The last time an interest payment was made
    uint256 public timeSinceLastInterestPayment = block.timestamp;

    /// @notice The `fullUtilizationRate` returned from the variable rate oracle
    uint256 public fullUtilizationRate;

    /// @notice Vault information for a given user
    mapping(address => Vault) public userVaults;

    /// @notice arrays of all BAMM users
    address[] public users;

    /// @notice mapping of all BAMM users
    mapping(address => bool) public isUser;

    /// @notice Max Oracle deviation per pair
    uint256 public maxOracleDiff = 250;

    // #######################################
    // ############## CONSTANTS ##############
    // #######################################

    /// @notice The precision to use and conform to
    uint256 public constant PRECISION = 1e18;

    /// @notice Percent above which the position is considered insolvent and can be liquidated
    uint256 public constant SOLVENCY_THRESHOLD_LIQUIDATION = (980 * PRECISION) / 1000; // 98%

    /// @notice Percent at wich the position can be liquidated with the max fee
    uint256 public constant SOLVENCY_THRESHOLD_FULL_LIQUIDATION = (990 * PRECISION) / 1000; // 99%

    /// @notice Protocol's cut of the interest rate
    uint256 public constant FEE_SHARE = (10 * 10_000) / 100; // 10%

    /// @notice The fee when a liquidation occurs
    uint256 public constant LIQUIDATION_FEE = 10_000; // 1%

    /// @notice The maximum utility rate for an LP
    uint256 public constant MAX_UTILITY_RATE = (PRECISION * 95) / 100; // 95%

    /// @notice The minimum liquidity allowed for the pool
    uint256 public constant MINIMUM_LIQUIDITY = 1e4;

    // #########################################
    // ############## Constructor ##############
    // #########################################

    constructor(bytes memory _encodedBammConstructorArgs) {
        (
            uint256 _id,
            address _pair,
            address _fraxswapRouter,
            address _fraxswapOracle,
            address _variableInterestRateAddress,
            uint64 startFullUtilRate
        ) = abi.decode(_encodedBammConstructorArgs, (uint256, address, address, address, address, uint64));

        // fill in state variables
        pair = IFraxswapPair(_pair);
        pairFactory = IFraxswapFactory(IFraxswapPair(_pair).factory());
        token0 = IERC20(pair.token0());
        token1 = IERC20(pair.token1());
        routerMultihop = IFraxswapRouterMultihop(_fraxswapRouter);
        fraxswapOracle = IFraxswapOracle(_fraxswapOracle);
        factory = msg.sender;
        variableInterestRate = IVariableInterestRate(_variableInterestRateAddress);
        fullUtilizationRate = startFullUtilRate;

        // Create BAMM ERC20
        iBammErc20 = new BAMMERC20(address(token0), address(token1), _id.toString());
    }

    /// @notice Semantic version of this contract
    /// @return _major The major version
    /// @return _minor The minor version
    /// @return _patch The patch version
    function version() external pure returns (uint256 _major, uint256 _minor, uint256 _patch) {
        return (0, 5, 2);
    }

    // ############################################
    // ############## Lender actions ##############
    // ############################################

    /// @notice Mint BAMM wrapper tokens with LP tokens
    /// @param to Destination address for the wrapper tokens
    /// @param lpIn The amount of Fraxswap LP to wrap
    /// @return bammOut The amount of BAMM tokens generated
    /// @dev Make sure to approve first
    function mint(address to, uint256 lpIn) external nonReentrant returns (uint256 bammOut) {
        // Sync the LP, then add the interest
        (uint112 reserve0, uint112 reserve1, uint256 pairTotalSupply) = _addInterest();

        // Calculate the LP to BAMM conversion
        uint256 sqrtReserve = Math.sqrt(uint256(reserve0) * reserve1);
        uint256 sqrtAmount = (lpIn * sqrtReserve) / pairTotalSupply;
        uint256 balance = pair.balanceOf(address(this));

        // Take the LP from the sender and mint them BAMM wrapper tokens
        uint256 totalSupply_ = iBammErc20.totalSupply();
        if (totalSupply_ == 0) {
            // At 0 supply, mint initial liquidity and lock it
            bammOut = sqrtAmount - MINIMUM_LIQUIDITY;
            iBammErc20.mint(address(1), MINIMUM_LIQUIDITY);
        } else {
            uint256 sqrtBalance = (balance * sqrtReserve) / pairTotalSupply;
            if ((sqrtBalance * pairTotalSupply) / sqrtReserve < balance) sqrtBalance += 1;
            uint256 sqrtRentedReal = (uint256(sqrtRented) * rentedMultiplier) / PRECISION;
            if ((sqrtRentedReal * PRECISION) / rentedMultiplier < uint256(sqrtRented)) sqrtRentedReal += 1;
            bammOut = (sqrtAmount * totalSupply_) / (sqrtBalance + sqrtRentedReal);
        }
        /// Revert if lpIn == 0 as sqrtAmount = 0 and in rounding down small amounts
        if (bammOut == 0) revert ZeroLiquidityMinted();

        // Transfer LP token to bamm and give `to` the BAMM wrapper tokens
        SafeERC20.safeTransferFrom({ token: IERC20(address(pair)), from: msg.sender, to: address(this), value: lpIn });
        iBammErc20.mint({ account: ((to == address(0)) ? msg.sender : to), value: bammOut });

        emit BAMMMinted({ lender: msg.sender, recipient: to, lpIn: lpIn, bammOut: bammOut });
        _emitBAMMState(reserve0, reserve1, pairTotalSupply);
    }

    /// @notice Redeem BAMM wrapper tokens for LP tokens
    /// @param to Destination address for the LP tokens
    /// @param bammIn The amount of BAMM tokens to redeem for Fraxswap LP
    /// @return lpOut The amount of LP tokens generated
    function redeem(address to, uint256 bammIn) external nonReentrant returns (uint256 lpOut) {
        // Sync the LP, then add the interest
        (uint112 reserve0, uint112 reserve1, uint256 pairTotalSupply) = _addInterest();

        // Calculate the BAMM to LP conversion
        uint256 sqrtToRedeem;
        uint256 sqrtReserve;
        {
            uint256 balance = pair.balanceOf(address(this));
            sqrtReserve = Math.sqrt(uint256(reserve0) * reserve1);
            uint256 sqrtBalance = (balance * sqrtReserve) / pairTotalSupply;
            uint256 sqrtRentedReal = (uint256(sqrtRented) * rentedMultiplier) / PRECISION;
            sqrtToRedeem = (bammIn * (sqrtBalance + sqrtRentedReal)) / iBammErc20.totalSupply();
        }

        // Burn the BAMM wrapper tokens from the sender and give them LP
        if (sqrtToRedeem > 0) {
            lpOut = (sqrtToRedeem * pairTotalSupply) / sqrtReserve;
            SafeERC20.safeTransfer({
                token: IERC20(address(pair)),
                to: (to == address(0) ? msg.sender : to),
                value: lpOut
            });
        }
        iBammErc20.burn({ account: msg.sender, value: bammIn });

        // Max sure the max utility is within acceptable range
        if (!_isValidUtilityRate({ reserve0: reserve0, reserve1: reserve1, pairTotalSupply: pairTotalSupply })) {
            revert InvalidUtilityRate();
        }

        emit BAMMRedeemed({ lender: msg.sender, recipient: to, bammIn: bammIn, lpOut: lpOut });
        _emitBAMMState(reserve0, reserve1, pairTotalSupply);
    }

    // ############################################
    // ############# Borrower actions #############
    // ############################################

    /// @notice Execute actions
    /// @param action The details of the action to be executed
    /// @return vault Ending vault state
    function executeActions(Action memory action) public returns (Vault memory vault) {
        IFraxswapRouterMultihop.FraxswapParams memory swapParams;
        return executeActionsAndSwap({ action: action, swapParams: swapParams });
    }

    /// @notice Calculate total supply adjustment due to protocol fees in the Fraxswap pair.
    /// @dev see: https://github.com/FraxFinance/dev-fraxswap/blob/9744c757f7e51c1deee3f5db50d3aaec495aea01/src/contracts/core/FraxswapPair.sol#L317
    /// @param reserve0 The reserves for token0 of the pair
    /// @param reserve1 The reserves for token1 of the pair
    /// @param totalSupply The total supply of the pair token
    /// @return tsAdjustment The total supply adjustment of the lp token due to fees
    function _calcMintedSupplyFromPairMintFee(
        uint256 reserve0,
        uint256 reserve1,
        uint256 totalSupply
    ) internal view returns (uint256 tsAdjustment) {
        if (pairFactory.feeTo() != address(0)) {
            uint256 kLast = pair.kLast();
            if (kLast != 0) {
                uint256 rootK = Math.sqrt(uint256(reserve0) * reserve1);
                uint256 rootKLast = Math.sqrt(kLast);
                if (rootK > rootKLast) {
                    uint256 num = totalSupply * (rootK - rootKLast);
                    uint256 denom = (rootK * 5) + rootKLast;
                    tsAdjustment = num / denom;
                }
            }
        }
    }

    function _syncVault(
        Vault memory _vault,
        int256 _rent,
        uint112 _reserve0,
        uint112 _reserve1,
        uint256 _pairTotalSupply
    ) internal returns (int256 lpTokenAmount, int256 token0Amount, int256 token1Amount) {
        // Calculate the amount of LP, token0, and token1
        int256 rentedMultiplierAsInt = rentedMultiplier.toInt256(); // gas
        int256 sqrtAmountRented = (_rent * rentedMultiplierAsInt) / 1e18;
        int256 sqrtReserves = int256(Math.sqrt(uint256(_reserve0) * _reserve1));
        if (_rent < 0) {
            if (((sqrtAmountRented * 1e18) / rentedMultiplierAsInt) > _rent) sqrtAmountRented -= 1;
        }
        lpTokenAmount = (sqrtAmountRented * _pairTotalSupply.toInt256()) / sqrtReserves;
        if (_rent < 0) {
            if (((lpTokenAmount * sqrtReserves) / _pairTotalSupply.toInt256()) > sqrtAmountRented) {
                lpTokenAmount -= 1;
            }
        }
        token0Amount = (int256(uint256(_reserve0)) * lpTokenAmount) / _pairTotalSupply.toInt256();
        token1Amount = (int256(uint256(_reserve1)) * lpTokenAmount) / _pairTotalSupply.toInt256();

        if (_rent < 0) {
            if (((token0Amount * _pairTotalSupply.toInt256()) / _reserve0.toInt256()) > lpTokenAmount) {
                token0Amount -= 1;
            }
            if (((token1Amount * _pairTotalSupply.toInt256()) / _reserve1.toInt256()) > lpTokenAmount) {
                token1Amount -= 1;
            }
        }

        // Update the rent and credit the user some token0 and token1
        _vault.rented += _rent;
        _vault.token0 += token0Amount;
        _vault.token1 += token1Amount;

        // Update the total rented liquidity
        sqrtRented += _rent;
    }

    /// @dev _rent is positive
    function _borrow(
        Vault memory _vault,
        int256 _rent,
        uint112 _reserve0,
        uint112 _reserve1,
        uint256 _pairTotalSupply
    ) internal {
        if (sqrtRented == 0 && iBammErc20.totalSupply() == 0) revert NoBAMMTokensMinted();
        (int256 lpTokenAmount, int256 token0Amount, int256 token1Amount) = _syncVault({
            _vault: _vault,
            _rent: _rent,
            _reserve0: _reserve0,
            _reserve1: _reserve1,
            _pairTotalSupply: _pairTotalSupply
        });

        // Transfer LP to the LP contract, then optimistically burn it there to release token0 and token1 to this contract
        // The tokens will be given to the borrower later, assuming action.token0Amount and/or action.token1Amount is negative
        SafeERC20.safeTransfer({ token: IERC20(address(pair)), to: address(pair), value: uint256(lpTokenAmount) });
        pair.burn(address(this));

        emit Renting({ user: msg.sender, rent: _rent, token0Amount: token0Amount, token1Amount: token1Amount });
    }

    /// @dev rent is negative
    function _repay(
        Vault memory _vault,
        int256 _rent,
        uint112 _reserve0,
        uint112 _reserve1,
        uint256 _pairTotalSupply,
        uint256 _token0AmountMin,
        uint256 _token1AmountMin
    ) internal returns (uint256 token0ToAddToLp, uint256 token1ToAddToLp) {
        (, int256 token0Amount, int256 token1Amount) = _syncVault({
            _vault: _vault,
            _rent: _rent,
            _reserve0: _reserve0,
            _reserve1: _reserve1,
            _pairTotalSupply: _pairTotalSupply
        });

        // token0Amount and token1Amount are negative as they subtracted balances from the vault, so we need to convert positive
        token0ToAddToLp = uint256(-token0Amount);
        token1ToAddToLp = uint256(-token1Amount);

        // Avoid sandwich attacks
        if ((token0ToAddToLp < _token0AmountMin) || (token1ToAddToLp < _token1AmountMin)) {
            revert InsufficientAmount();
        }
    }

    /// @notice Execute actions and also do a swap
    /// @param action The details of the action to be executed
    /// @param swapParams The details of the swap to be executed
    /// @return vault Ending vault state
    function executeActionsAndSwap(
        Action memory action,
        IFraxswapRouterMultihop.FraxswapParams memory swapParams
    ) public nonReentrant returns (Vault memory vault) {
        // Get the existing vault info for the user
        vault = userVaults[msg.sender];

        // Add to users array if needed.
        if (!isUser[msg.sender]) {
            isUser[msg.sender] = true;
            users.push(msg.sender);
        }

        // Sync the LP, then add the interest
        (uint112 reserve0, uint112 reserve1, uint256 pairTotalSupply) = _addInterest();

        // Note if the user is closing the position
        if (action.closePosition) {
            if (action.rent != 0) revert InvalidRent();
            action.rent = -vault.rented;
        }

        // Rent LP constituent tokens (if specified). Positive rent means borrowing
        if (action.rent > 0) {
            _borrow({
                _vault: vault,
                _rent: action.rent,
                _reserve0: reserve0,
                _reserve1: reserve1,
                _pairTotalSupply: pairTotalSupply
            });
        }

        // If specified in the action, add tokens to the vault (vault is modified by reference)
        // Positive token0Amount and/or token1Amount means add from vault
        if (action.token0Amount > 0 || action.token1Amount > 0) _addTokensToVault({ _vault: vault, _action: action });

        // Execute the swap if there are swapParams
        if (swapParams.amountIn != 0) {
            // Do the swap
            _executeSwap(vault, swapParams);

            // Swap might have changed the reserves of the pair.
            (reserve0, reserve1, pairTotalSupply) = _addInterest();
        }

        // Return rented LP constituent tokens (if specified) to this contract.
        // Negative rent means repaying but not closing.
        uint256 token0ToAddToLp;
        uint256 token1ToAddToLp;
        if (action.rent < 0) {
            (token0ToAddToLp, token1ToAddToLp) = _repay({
                _vault: vault,
                _rent: action.rent,
                _reserve0: reserve0,
                _reserve1: reserve1,
                _pairTotalSupply: pairTotalSupply,
                _token0AmountMin: action.token0AmountMin,
                _token1AmountMin: action.token1AmountMin
            });
        }

        // Close the position (if specified)
        if (action.closePosition) {
            // You might have some leftover tokens you can withdraw later if you over-collateralized
            action.token0Amount = -vault.token0;
            action.token1Amount = -vault.token1;
            _addTokensToVault({ _vault: vault, _action: action });
        }

        // Return rented LP constituent tokens (continued from above)
        // This portion recovers the LP and gives it to this BAMM contract
        if (token0ToAddToLp > 0) {
            // Send token0 and token1 directly to the LP address
            SafeERC20.safeTransfer({ token: token0, to: address(pair), value: token0ToAddToLp });
            SafeERC20.safeTransfer({ token: token1, to: address(pair), value: token1ToAddToLp });

            // Mint repayed LP last, so we know we have enough tokens in the contract
            pair.mint(address(this));

            emit RentRepaid({
                user: msg.sender,
                rent: -action.rent,
                token0ToAddToLp: token0ToAddToLp,
                token1ToAddToLp: token1ToAddToLp,
                closePosition: action.closePosition
            });
        }

        // Remove token0 from the vault and give to the user (if specified)
        // Negative token0Amount means remove from vault
        if (action.token0Amount < 0) {
            if (action.to == address(this)) revert CannotWithdrawToSelf();
            _moveTokenForVault({
                _vault: vault,
                _token: token0,
                _to: (action.to == address(0) ? msg.sender : action.to),
                _tokenAmount: action.token0Amount
            });
        }

        // Remove token1 from the vault and give to the user (if specified)
        // Negative token1Amount means remove from vault
        if (action.token1Amount < 0) {
            if (action.to == address(this)) revert CannotWithdrawToSelf();
            _moveTokenForVault({
                _vault: vault,
                _token: token1,
                _to: (action.to == address(0) ? msg.sender : action.to),
                _tokenAmount: action.token1Amount
            });
        }
        emit ExecuteAction({
            user: msg.sender,
            token0: action.token0Amount,
            token1: action.token1Amount,
            rent: action.rent
        });
        emit VaultUpdated({ user: msg.sender, token0: vault.token0, token1: vault.token1, rent: vault.rented });
        _emitBAMMState(reserve0, reserve1, pairTotalSupply);

        // Write the final vault state to storage after all the above operations are completed
        userVaults[msg.sender] = vault;

        // Make sure the user is still solvent
        if (!_solvent(vault, SOLVENCY_THRESHOLD_LIQUIDATION)) {
            revert NotSolvent();
        }

        // Check max utility after a rent
        if (action.rent > 0) {
            if (!_isValidUtilityRate({ reserve0: reserve0, reserve1: reserve1, pairTotalSupply: pairTotalSupply })) {
                revert InvalidUtilityRate();
            }
        }
    }

    function _moveTokenForVault(Vault memory _vault, IERC20 _token, address _to, int256 _tokenAmount) internal {
        // NOTE: _tokenAmount is negative when withdrawing from vault and positive when depositing to vault
        if (_token == token0) {
            _vault.token0 += _tokenAmount;
        } else {
            // _token == token1
            /// @dev _token will always be either token0 or token1
            _vault.token1 += _tokenAmount;
        }

        if (_to == address(this)) {
            // deposit
            SafeERC20.safeTransferFrom({
                token: _token,
                from: msg.sender,
                to: address(this), // for clarity
                value: uint256(_tokenAmount)
            });
        } else {
            // withdrawal (_tokenAmount is currently negative)
            SafeERC20.safeTransfer({ token: _token, to: _to, value: uint256(-_tokenAmount) });
        }
    }

    function _emitBAMMState(uint256 reserve0, uint256 reserve1, uint256 pairTotalSupply) internal {
        uint256 rentedMultiplier_ = rentedMultiplier;
        uint256 balance = pair.balanceOf(address(this));
        uint256 sqrtReserve = Math.sqrt(uint256(reserve0) * reserve1);
        uint256 sqrtBalance = pairTotalSupply == 0 ? 0 : ((balance * sqrtReserve) / pairTotalSupply);
        uint256 sqrtRentedReal = (uint256(sqrtRented) * rentedMultiplier_) / PRECISION;
        uint256 utilityRate;
        if (sqrtBalance + sqrtRentedReal > 0) {
            utilityRate = (uint256(sqrtRentedReal) * PRECISION) / (sqrtBalance + sqrtRentedReal);
        }
        uint256 interestRate = _getVariableInterestRate(0, utilityRate);
        emit BAMMState({
            sqrtRentedReal: sqrtRentedReal,
            sqrtBalance: sqrtBalance,
            rentedMultiplier: rentedMultiplier_,
            interestRate: interestRate
        });
    }

    // ############################################
    // ############ Liquidator actions ############
    // ############################################

    // Approximates how much of a token must be sold in a vault for the ratio in the vault to be the same as the ratio in the AMM.
    function getMaxSell(
        uint256 tokenIn,
        uint256 tokenOut,
        uint256 reserveIn,
        uint256 reserveOut
    ) public pure returns (uint256 maxSell) {
        // Solve x for: (reserveOut-y)/(reserveIn+x) = (tokenOut+y)/(tokenIn-x), (reserveOut-y)*(reserveIn+x)=reserveIn*reserveOut
        uint256 prod = Math.sqrt(reserveOut * reserveIn) * Math.sqrt((reserveOut + tokenOut) * (reserveIn + tokenIn));
        uint256 minus = reserveIn * tokenOut + reserveOut * reserveIn;
        if (prod > minus) maxSell = (prod - minus) / (reserveOut + tokenOut);
    }

    // Calculates how much of the vault is being repayed, based on the LTV
    // Starts at 0.25%, goes to 20% half way and up to 100% at the end.
    function repayPercentage(uint256 _ltv) internal pure returns (uint256 _repayPercentage) {
        uint256 kink = (SOLVENCY_THRESHOLD_FULL_LIQUIDATION + SOLVENCY_THRESHOLD_LIQUIDATION) / 2;
        if (_ltv > SOLVENCY_THRESHOLD_FULL_LIQUIDATION) {
            _repayPercentage = 1e18;
        } else if (_ltv > kink) {
            _repayPercentage = 0.2e18 + (0.8e18 * (_ltv - kink)) / (SOLVENCY_THRESHOLD_FULL_LIQUIDATION - kink);
        } else {
            _repayPercentage =
                0.002e18 +
                (0.198e18 * (_ltv - SOLVENCY_THRESHOLD_LIQUIDATION)) /
                (kink - SOLVENCY_THRESHOLD_LIQUIDATION);
        }
    }

    /// @notice Auctioned micro-liquidation by doing a small swap and paying back rented liquidity
    /// @param user The user to be micro-liquidated
    /// @return token0Fee The number of token0 received as liquidation fee
    /// @return token1Fee The number of token1 received as liquidation fee
    function microLiquidate(address user) external nonReentrant returns (uint256 token0Fee, uint256 token1Fee) {
        // Sync the LP, then add the interest
        (uint112 reserve0, uint112 reserve1, uint256 pairTotalSupply) = _addInterest();

        // Compare the spot price from the reserves to the oracle price. Revert if they are off by too much.
        ammPriceCheck(reserve0, reserve1);

        // Get the existing vault info for the user
        Vault memory vault = userVaults[user];

        // Make sure the user is NOT solvent for micro liquidations
        uint256 _ltv = ltv(vault);
        if (_ltv < SOLVENCY_THRESHOLD_LIQUIDATION) revert("User solvent");
        uint256 sqrtToLiquidity;
        uint256 _repayPercentage = repayPercentage(_ltv);
        if (uint256(vault.token0) > (uint256(vault.token1) * reserve0) / reserve1) {
            // Excess token0, swap token0 to token1
            uint256 maxSell = getMaxSell(
                uint256(vault.token0),
                uint256(vault.token1),
                uint256(reserve0),
                uint256(reserve1)
            );
            // sellPercentage is twice the repay percentage (capped at 100%)
            uint256 sellPercentage = _repayPercentage > 0.498e18 ? 1e18 : 0.004e18 + _repayPercentage * 2;
            uint256 sellToken0 = (maxSell * sellPercentage) / PRECISION;
            // Cap the amount sold to 1/350 of the total liquidity, to avoid high slippage
            if (sellPercentage < 0.1e18 && sellToken0 > reserve0 / 350) {
                sellToken0 = reserve0 / 350;
                sellPercentage = (sellToken0 * PRECISION) / maxSell;
            }
            if (sellToken0 > 0) {
                uint256 token1Out = getAmountOut(reserve0, reserve1, sellToken0, pair.fee());
                if (sellToken0 == reserve0 / 350) {
                    // At most repay from swapped amount when capped
                    _repayPercentage = Math.min(
                        _repayPercentage,
                        (token1Out * PRECISION) / (token1Out + uint256(vault.token1))
                    );
                }
                if (token1Out > 0) {
                    // Do the swap
                    SafeERC20.safeTransfer(token0, address(pair), sellToken0);
                    pair.swap(0, token1Out, address(this), "");
                    vault.token0 -= int256(sellToken0);
                    vault.token1 += int256(token1Out);
                    reserve0 += uint112(sellToken0);
                    reserve1 -= uint112(token1Out);
                    emit VaultSwap({ user: user, token0: -int256(sellToken0), token1: int256(token1Out) });
                }
            }
            // If the pool has small reserves & the vault is not up for full liquidation
            // limit the repay % to 1/25th of the reserves in the pool
            if (
                _ltv < SOLVENCY_THRESHOLD_FULL_LIQUIDATION &&
                uint256(vault.token1) * _repayPercentage > (reserve1 * PRECISION) / 25
            ) _repayPercentage = (reserve1 * PRECISION) / (25 * uint256(vault.token1));
            uint256 token1ToLiquidity = (uint256(vault.token1) * _repayPercentage) / PRECISION;
            sqrtToLiquidity = Math.sqrt(token1ToLiquidity * ((token1ToLiquidity * reserve0) / reserve1));
        } else {
            // Excess token1, swap token1 to token0
            uint256 maxSell = getMaxSell(
                uint256(vault.token1),
                uint256(vault.token0),
                uint256(reserve1),
                uint256(reserve0)
            );
            // sellPercentage is twice the repay percentage (capped at 100%)
            uint256 sellPercentage = _repayPercentage > 0.498e18 ? 1e18 : 0.004e18 + _repayPercentage * 2;
            uint256 sellToken1 = (maxSell * sellPercentage) / PRECISION;
            // Cap the amount sold to 1/350 of the total liquidity, to avoid high slippage
            if (sellPercentage < 0.1e18 && sellToken1 > reserve1 / 350) {
                sellToken1 = reserve1 / 350;
                sellPercentage = (sellToken1 * PRECISION) / maxSell;
            }
            if (sellToken1 > 0) {
                uint256 token0Out = getAmountOut(reserve1, reserve0, sellToken1, pair.fee());
                if (sellToken1 == reserve1 / 350) {
                    // At most repay from swapped amount when capped
                    _repayPercentage = Math.min(
                        _repayPercentage,
                        (token0Out * PRECISION) / (token0Out + uint256(vault.token0))
                    );
                }
                if (token0Out > 0) {
                    // Do the swap
                    SafeERC20.safeTransfer(token1, address(pair), sellToken1);
                    pair.swap(token0Out, 0, address(this), "");
                    vault.token0 += int256(token0Out);
                    vault.token1 -= int256(sellToken1);
                    reserve0 -= uint112(token0Out);
                    reserve1 += uint112(sellToken1);
                    emit VaultSwap({ user: user, token0: int256(token0Out), token1: -int256(sellToken1) });
                }
            }
            // If the pool has small reserves & the vault is not up for full liquidation
            // limit the repay % to 1/25th of the reserves in the pool
            if (
                _ltv < SOLVENCY_THRESHOLD_FULL_LIQUIDATION &&
                uint256(vault.token0) * _repayPercentage > (reserve0 * PRECISION) / 25
            ) _repayPercentage = (reserve0 * PRECISION) / (25 * uint256(vault.token0));
            uint256 token0ToLiquidity = (uint256(vault.token0) * _repayPercentage) / PRECISION;
            sqrtToLiquidity = Math.sqrt(token0ToLiquidity * ((token0ToLiquidity * reserve1) / reserve0));
        }
        int256 rentToLiquidity = int256((sqrtToLiquidity * PRECISION) / rentedMultiplier);

        if (rentToLiquidity > 0) {
            int256 liquidationFee = int256(
                _ltv > SOLVENCY_THRESHOLD_FULL_LIQUIDATION
                    ? LIQUIDATION_FEE
                    : (LIQUIDATION_FEE * (_ltv - SOLVENCY_THRESHOLD_LIQUIDATION)) /
                        (SOLVENCY_THRESHOLD_FULL_LIQUIDATION - SOLVENCY_THRESHOLD_LIQUIDATION)
            );
            rentToLiquidity = (rentToLiquidity * (1_000_000 - liquidationFee)) / 1_000_000;
            if (rentToLiquidity > vault.rented) rentToLiquidity = vault.rented;

            (reserve0, reserve1, pairTotalSupply) = _addInterest();
            (, int256 token0Amount, int256 token1Amount) = _syncVault(
                vault,
                -rentToLiquidity,
                reserve0,
                reserve1,
                pairTotalSupply
            );

            if (token0Amount < 0 || token1Amount < 0) {
                //Mint the LP tokens
                SafeERC20.safeTransfer({ token: token0, to: address(pair), value: uint256(-token0Amount) });
                SafeERC20.safeTransfer({ token: token1, to: address(pair), value: uint256(-token1Amount) });
                pair.mint(address(this));

                emit RentRepaid({
                    user: user,
                    rent: rentToLiquidity,
                    token0ToAddToLp: uint256(-token0Amount),
                    token1ToAddToLp: uint256(-token1Amount),
                    closePosition: false
                });
            }

            // Give the liquidation fee to the liquidator as a percentage of the liquidated value
            token0Fee = uint256((-token0Amount * liquidationFee) / (1_000_000 - liquidationFee));
            token1Fee = uint256((-token1Amount * liquidationFee) / (1_000_000 - liquidationFee));
            if (int256(token0Fee) > vault.token0 || int256(token1Fee) > vault.token1) {
                // When there are not enough tokens for the fee, give all tokens left as fee
                token0Fee = uint256(vault.token0);
                token1Fee = uint256(vault.token1);
            }
            vault.token0 -= int256(token0Fee);
            vault.token1 -= int256(token1Fee);

            if (vault.token0 == 0 || vault.token1 == 0 || (_repayPercentage == 1e18 && ltv(vault) > PRECISION)) {
                // Debt restructuring
                token0Fee += uint256(vault.token0);
                token1Fee += uint256(vault.token1);
                vault.token0 = 0;
                vault.token1 = 0;
                sqrtRented -= vault.rented;
                vault.rented = 0;
            }

            // Send liquidation fee to the liquidator
            SafeERC20.safeTransfer(IERC20(address(token0)), msg.sender, token0Fee);
            SafeERC20.safeTransfer(IERC20(address(token1)), msg.sender, token1Fee);
            emit MicroLiquidate({ user: user, liquidator: msg.sender, token0Fee: token0Fee, token1Fee: token1Fee });
        }
        emit VaultUpdated({ user: user, token0: vault.token0, token1: vault.token1, rent: vault.rented });
        _emitBAMMState(reserve0, reserve1, pairTotalSupply);

        // Write the final vault state to storage
        if (!_isValidVault(vault)) revert InvalidVault();
        userVaults[user] = vault;
    }

    function getAmountOut(
        uint256 reserveIn,
        uint256 reserveOut,
        uint256 amountIn,
        uint256 fee
    ) internal pure returns (uint256) {
        require(amountIn > 0 && reserveIn > 0 && reserveOut > 0); // INSUFFICIENT_INPUT_AMOUNT, INSUFFICIENT_LIQUIDITY
        uint256 amountInWithFee = amountIn * fee;
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = (reserveIn * 10_000) + amountInWithFee;
        return numerator / denominator;
    }

    // ############################################
    // ############# Factory functions ############
    // ############################################

    /// @notice Update the interest rate contract
    /// @param newVariableInterestRate the new interest rate contract
    function setVariableInterestRate(address newVariableInterestRate) external {
        if (msg.sender != factory) revert NotFactory();
        emit NewVariableInterestRate(address(variableInterestRate), newVariableInterestRate);
        variableInterestRate = IVariableInterestRate(newVariableInterestRate);
    }

    /// @notice Update the maximum oracle deviation on the bamm
    /// @param newMaxDiff The new max % difference between twap and spot
    /// @dev percent in denomination of 1e5
    function setMaxOracleDeviation(uint256 newMaxDiff) external {
        if (msg.sender != factory) revert NotFactory();
        emit NewMaxOracleDiff(maxOracleDiff, newMaxDiff);
        maxOracleDiff = newMaxDiff;
    }

    // ############################################
    // ############# External utility #############
    // ############################################

    /// @notice Accrue interest payments
    /// @return reserve0 The LP's reserve0
    /// @return reserve1 The LP's reserve1
    /// @return totalSupply The LP's totalSupply()
    /// @return _rentedMultiplier rentedMultiplier after interest calculation
    function addInterest()
        external
        nonReentrant
        returns (uint256 reserve0, uint256 reserve1, uint256 totalSupply, uint256 _rentedMultiplier)
    {
        (reserve0, reserve1, totalSupply) = _addInterest();
        _rentedMultiplier = rentedMultiplier;
        _emitBAMMState(reserve0, reserve1, totalSupply);
    }

    /// @notice Get the interest rate at the specified _utilization
    /// @param _deltaTime The time in seconds between now and the previous interest accrual
    /// @param _utilization The internal Bamm Utilization represented in 1e18 w/ a max of MAX_UTILITY_RATE
    /// @return newRatePerSec The interest rate per second
    function _getVariableInterestRate(
        uint256 _deltaTime,
        uint256 _utilization
    ) internal returns (uint256 newRatePerSec) {
        uint256 utilScaled = (_utilization * 1e5) / MAX_UTILITY_RATE;
        (newRatePerSec, fullUtilizationRate) = variableInterestRate.getNewRate(
            _deltaTime,
            utilScaled,
            uint64(fullUtilizationRate)
        );
    }

    /// @notice public view function to view the calculated interest rate at a given utilization
    /// @param _utilization The internal Bamm Utilization represented in 1e18 w/ a max of MAX_UTILITY_RATE
    /// @return newRatePerSec The interest rate per second
    function previewInterestRate(uint256 _utilization) public view returns (uint256 newRatePerSec) {
        uint256 utilScaled = (_utilization * 1e5) / MAX_UTILITY_RATE;
        uint256 period = block.timestamp - timeSinceLastInterestPayment;
        (newRatePerSec, ) = variableInterestRate.getNewRate(period, utilScaled, uint64(fullUtilizationRate));
    }

    // ############################################
    // ################# Internal #################
    // ############################################

    /// @notice Transfers LP constituent tokens from the user to this contract, and marks it as part of their vault.
    /// @param _vault The _vault you are modifying
    /// @param _action The _action
    /// @dev _vault is passed by reference, so it modified in the caller
    function _addTokensToVault(Vault memory _vault, Action memory _action) internal {
        // Approve via permit
        if (_action.v != 0 && (_action.token0Amount > 0 || _action.token1Amount > 0)) {
            // Determine the token of the permit
            IERC20 token = _action.token0Amount > 0 ? token0 : token1;

            // Do the permit
            uint256 amount = _action.approveMax
                ? type(uint256).max
                : uint256(_action.token0Amount > 0 ? _action.token0Amount : _action.token1Amount);
            IERC20Permit(address(token)).permit({
                owner: msg.sender,
                spender: address(this),
                value: amount,
                deadline: _action.deadline,
                v: _action.v,
                r: _action.r,
                s: _action.s
            });

            // Clear out v to prevent a potential duplicate failing permit
            _action.v = 0;
        }

        // Add token0 to the vault
        if (_action.token0Amount > 0) {
            _moveTokenForVault({
                _vault: _vault,
                _token: token0,
                _to: address(this),
                _tokenAmount: _action.token0Amount
            });
        }

        // Add token1 to the vault
        if (_action.token1Amount > 0) {
            _moveTokenForVault({
                _vault: _vault,
                _token: token1,
                _to: address(this),
                _tokenAmount: _action.token1Amount
            });
        }
    }

    /// @notice Swaps tokens in the users vault
    /// @param vault The vault you are modifying
    /// @param swapParams Info about the swap. Is modified
    /// @dev vault and swapParams are passed by reference, so they modified in the caller
    function _executeSwap(Vault memory vault, IFraxswapRouterMultihop.FraxswapParams memory swapParams) internal {
        // Make sure the order of the swap is one of two directions
        if (
            !(swapParams.tokenIn == address(token0) && swapParams.tokenOut == address(token1)) &&
            !(swapParams.tokenIn == address(token1) && swapParams.tokenOut == address(token0))
        ) {
            revert IncorrectSwapTokens();
        }

        // Approve the input token to the router
        SafeERC20.safeIncreaseAllowance({
            token: IERC20(swapParams.tokenIn),
            spender: address(routerMultihop),
            value: swapParams.amountIn
        });

        // Set the recipient to this address
        swapParams.recipient = address(this);

        // Require an amountOutMinimum to avoid bad swaps
        if (swapParams.amountOutMinimum == 0) revert IncorrectAmountOutMinimum();

        // Router checks the minAmountOut
        /// @dev: ensure swapParams are correct - fat-fingered route data may result in lost funds
        /// @dev: we trust the output of the routerMultihop, token transfered in and out are checked in the router
        uint256 amountOut = routerMultihop.swap(swapParams);
        if (swapParams.tokenIn == address(token0)) {
            vault.token0 -= swapParams.amountIn.toInt256();
            vault.token1 += amountOut.toInt256();
            emit VaultSwap({
                user: msg.sender,
                token0: -int256(swapParams.amountIn.toInt256()),
                token1: int256(amountOut.toInt256())
            });
        } else {
            vault.token1 -= swapParams.amountIn.toInt256();
            vault.token0 += amountOut.toInt256();
            emit VaultSwap({
                user: msg.sender,
                token0: int256(amountOut.toInt256()),
                token1: -int256(swapParams.amountIn.toInt256())
            });
        }
    }

    /// @notice Sync the LP and accrue interest
    /// @return reserve0 The LP's reserve0
    /// @return reserve1 The LP's reserve1
    /// @return pairTotalSupply The LP's totalSupply()
    function _addInterest() internal returns (uint112 reserve0, uint112 reserve1, uint256 pairTotalSupply) {
        // We need to call sync for Fraxswap pairs first to execute TWAMMs
        pair.sync();

        // Get the total supply and the updated reserves
        (reserve0, reserve1, ) = pair.getReserves();
        pairTotalSupply = pair.totalSupply();
        pairTotalSupply += _calcMintedSupplyFromPairMintFee(reserve0, reserve1, pairTotalSupply);

        // Calculate and accumulate interest if time has passed
        uint256 period = block.timestamp - timeSinceLastInterestPayment;
        uint256 sqrtRentedAsUint = sqrtRented.toUint256(); // gas
        uint256 rentedMultiplier_ = rentedMultiplier; // gas
        uint256 sqrtReserve = Math.sqrt(uint256(reserve0) * reserve1);
        if (period > 0) {
            // If there are outstanding rents, proceed
            if (sqrtRentedAsUint > 0) {
                // Do the interest calculations
                uint256 balance = pair.balanceOf(address(this));
                uint256 sqrtBalance = (balance * sqrtReserve) / pairTotalSupply;
                if ((sqrtBalance * pairTotalSupply) / sqrtReserve < balance) sqrtBalance += 1;
                uint256 sqrtRentedReal = (sqrtRentedAsUint * rentedMultiplier_) / PRECISION;
                if ((sqrtRentedReal * PRECISION) / rentedMultiplier < sqrtRentedAsUint) sqrtRentedReal += 1;
                uint256 utilityRate = (uint256(sqrtRentedReal) * PRECISION) / (sqrtBalance + sqrtRentedReal);

                uint256 interestRate = _getVariableInterestRate(period, utilityRate);
                uint256 deltaMultiplier = (rentedMultiplier_ * interestRate * period) / PRECISION;

                // Update the rentedMultiplier
                // The original lender will get more LP back as their "earnings" when they redeem their BAMM tokens
                rentedMultiplier_ += deltaMultiplier;

                // Give the fee recipient their cut of the fee, directly as BAMM tokens
                {
                    address feeTo = IBAMMFactory(factory).feeTo();
                    if (feeTo != address(0)) {
                        // accrue fee 10% of the sqrtK growth
                        uint256 feesAmount = (deltaMultiplier * sqrtRentedAsUint * FEE_SHARE) / (10_000 * PRECISION);
                        uint256 feeMintAmount = (feesAmount * iBammErc20.totalSupply()) /
                            (sqrtBalance + ((sqrtRentedAsUint * rentedMultiplier_) / PRECISION) - feesAmount);
                        iBammErc20.mint(feeTo, feeMintAmount);
                    }
                }
                // Store updated rentedMultiplier
                rentedMultiplier = rentedMultiplier_;
            }

            // Update the timeSinceLastInterestPayment
            timeSinceLastInterestPayment = block.timestamp;
        }
    }

    function _isValidVault(Vault memory vault) internal pure returns (bool) {
        if (vault.rented < 0 || vault.token0 < 0 || vault.token1 < 0) {
            // A vault should never end with negative balances
            return false;
        } else if (vault.rented > 0 && (vault.token0 == 0 || vault.token1 == 0)) {
            // If a vault has outstanding rent, both token0 and token1 must not be 0
            return false;
        }
        return true;
    }

    function ltv(Vault memory vault) internal view returns (uint256) {
        if (vault.rented == 0) return 0;
        return (uint256(vault.rented) * rentedMultiplier) / Math.sqrt(uint256(vault.token0 * vault.token1));
    }

    function ltv(address user) public view returns (uint256) {
        return ltv(userVaults[user]);
    }

    /// @dev Helper to return Vault struct over tuple
    function getUserVault(address user) external view returns (Vault memory vault) {
        vault = userVaults[user];
    }

    /// @notice Is the vault solvent?
    /// @param vault The vault to check
    /// @param solvencyThreshold If vault ltv is at least this value, it is deemed insolvent
    /// @return bool If the vault is solvent
    function _solvent(Vault memory vault, uint256 solvencyThreshold) internal view returns (bool) {
        return _isValidVault(vault) && (vault.rented == 0 || ltv(vault) < solvencyThreshold);
    }

    function usersArray() external view returns (address[] memory) {
        return users;
    }

    function usersLength() external view returns (uint256) {
        return users.length;
    }

    /// @param reserve0 The LP's reserve0
    /// @param reserve1 The LP's reserve1
    /// @param pairTotalSupply The LP's totalSupply
    /// @return current utility rate
    function _currentUtilityRate(
        uint112 reserve0,
        uint112 reserve1,
        uint256 pairTotalSupply
    ) internal view returns (uint256) {
        uint256 sqrtRentedAsUint = sqrtRented.toUint256(); // gas
        if (sqrtRentedAsUint == 0) {
            return 0;
        }

        uint256 balance = pair.balanceOf(address(this));
        uint256 sqrtBalance = Math.sqrt(
            ((balance * reserve0) / pairTotalSupply) * ((balance * reserve1) / pairTotalSupply)
        );
        uint256 sqrtRentedReal = (sqrtRentedAsUint * rentedMultiplier) / PRECISION;
        uint256 utilityRate = (sqrtRentedReal * PRECISION) / (sqrtBalance + sqrtRentedReal);
        return utilityRate;
    }

    /// @dev Returns true if 0 <= {all outstanding rent} < MAX_UTILITY_RATE
    function _isValidUtilityRate(
        uint112 reserve0,
        uint112 reserve1,
        uint256 pairTotalSupply
    ) internal view returns (bool) {
        if (sqrtRented < 0) {
            return false;
        }
        if (
            _currentUtilityRate({ reserve0: reserve0, reserve1: reserve1, pairTotalSupply: pairTotalSupply }) >
            MAX_UTILITY_RATE
        ) {
            return false;
        }
        return true;
    }

    /// @notice Compare the spot price from the reserves to the oracle price. Revert if they are off by too much.
    /// @param reserve0 The LP's reserve0
    /// @param reserve1 The LP's reserve1
    function ammPriceCheck(uint112 reserve0, uint112 reserve1) internal view {
        // 30 minutes and max 2048 blocks
        (uint256 result0, uint256 result1) = fraxswapOracle.getPrice({
            pool: pair,
            period: 60 * 30,
            rounds: 11,
            maxDiffPerc: 10_000
        });
        result0 = 1e68 / result0;
        uint256 spotPrice = (uint256(reserve0) * 1e34) / reserve1;

        // Check the price differences and revert if they are too much
        uint256 diff = (spotPrice > result0 ? spotPrice - result0 : result0 - spotPrice);
        if ((diff * 10_000) / result0 > maxOracleDiff) {
            revert OraclePriceDeviated();
        }
        diff = (spotPrice > result1 ? spotPrice - result1 : result1 - spotPrice);
        if ((diff * 10_000) / result1 > maxOracleDiff) {
            revert OraclePriceDeviated();
        }
    }
}

//                          .,,.
//               ,;;<!;;;,'``<!!!!;,
//            =c,`<!!!!!!!!!>;``<!!!!>,
//         ,zcc;$$c`'!!!!!!!!!,;`<!!!!!>
//         .  $$$;F?b`!'!!!!!!!,    ;!!!!>
//      ;!; `",,,`"b " ;!!!!!!!!    .!!!!!!;
//     ;!>>;;  r'  :<!!!!!!!''''```,,,,,,,,,,,,.
//     ;!>;!>; ""):!```.,,,nmMMb`'!!!!!!!!!!!!!!!!!!!!!'''`,,,,;;;
//    <!!;;;;;''.,,ndMr'4MMMMMMMMb,``'''''''''''''',,;;<!!!!!!!!'
//   !!!'''''. "TMMMMMPJ,)MMMMMMMMMMMMMMMMMnmnmdM !!!!!!!!!!!!'
//   `.,nMbmnm $e."MMM J$ MMMMMMMMMMMMMMMMMMMMMP  `!!!!!!!''
//   .MMMMMMMM>$$$b 4 c$$>4MMMMMMM?MMMMM"MMM4M",M
//    4MMMMMMM>$$$P   "?$>,MMMMMP,dMMM",;M",",nMM
//    'MMMMMMM $$Ez$$$$$$>JMMM",MMMP .' .c nMMMMM
//     4Mf4MMP $$$$$$$$P"uP",uP"",zdc,'$$F;MMMfP
//      "M'MM d$$",="=,cccccc$$$$$$$$$$$P MMM"
//      \/\"f.$$$cb  ,b$$$$$$$" -."?$$$$ dP)"
//      `$c, $$$$$$$$$$",,,,"$$   "J$$$'J" ,c
//       `"$ $$$$$$P)3$ccd$,,$$$$$$$$$'',z$$F
//           `$$$$$$$`?$$$$$$"$$$$$$$P,c$P"
//             "?$$$$;=,""',c$$$$$$$"
//                `"??bc,,z$$$$PF""
//     .,,,,,,,,.    4c,,,,,
//  4$$$$$$$$$$$??$bd$$$$$P";!' ccd$$PF"  c,
//  4$$$$$$$$$P.d$$$$$?$P"<!! z$$$P",c$$$$$$$b.
//  `$$c,""??".$$$$$?4P';!!! J$$P'z$$$$$$$$$$P"
//   `?$$$$L z$$$$$$ C ,<!! $$$"J$$$?$$$PF"""
//    `?$$$".$$$$$$$F ;!!! zP" J$$$$-;;;
//     ,$$%z$$$$$$$";!!!' d$L`z?$?$" <!';
//  ..'$$"-",nr"$" !!!!! $$$$;3L?c"? `<>`;
//   "C": \'MMM ";!!!!!'<$$$$$        !! <;
//     <`.dMMT4bn`.!';! ???$$F        !!! <>
//    !!>;`T",;- !! emudMMb.??        <!!! <>
//   !<!!!!,,`''!!! `TMMMP",!!!>      !!!!!.`!
//    !!!!!!!!!>.`'!`:MMM.<!!!!       !!!!!!>`!;
//   !!!!!!`<!!!!!;,,`TT" <!!!,      ;!'.`'!!! <>
//  '!''<! ,.`!!!``!!!!'`!!! '!      !! <!:`'!!.`!;
//  '      ?",`! dc''`,r;`,-  `     ;!!!`!!!;`!!:`!>
//    cbccc$$$$c$$$bd$$bcd          `!!! <;'!;`!! !!>
//   <$$$$$$$$$$$$$?)$$P"            `!!! <! ! !!>`!!
//   d$$$$$$P$$?????""                `!!> !> ,!!',!!
// .$$$$$$   cccc$$$                   `!!>`!!!!! !!!
//  "$C" ",d$$$$$$$$                    `!!:`!!!! !!!
//      ` `,c$$$$""                       <!!;,,,<!!!
//                                         `!!!!!'`
//                                           `

// ------------------------------------------------
// https://asciiart.website/index.php?art=cartoons/flintstones
