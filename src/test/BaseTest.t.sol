// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import "frax-std/FraxTest.sol";
import "./Helpers.sol";
import "../Constants.sol" as Constants;
import { stdMath } from "forge-std/StdMath.sol";

import { deployBammHelper, BAMMHelper } from "../script/DeployBAMMHelper.s.sol";
import { deployBAMMUIHelper, BAMMUIHelper } from "../script/DeployBAMMUIHelper.s.sol";
import { deployFraxswapOracle, FraxswapOracle } from "../script/DeployFraxswapOracle.s.sol";
import { deployBammFactory, BAMMFactory } from "../script/DeployBAMMFactory.s.sol";
import { deployVariableInterestRate, VariableInterestRate } from "../script/DeployVariableInterestRate.s.sol";

import { ERC20Mock } from "./mocks/ERC20Mock.sol";

import { IBAMM, BAMM } from "../contracts/BAMM.sol";
import { BAMMERC20 } from "../contracts/BAMMERC20.sol";
import { BAMMUIHelper } from "../contracts/BAMMUIHelper.sol";

import { IFraxswapPair } from "dev-fraxswap/src/contracts/core/interfaces/IFraxswapPair.sol";
import { IFraxswapFactory } from "dev-fraxswap/src/contracts/core/interfaces/IFraxswapFactory.sol";
import { IFraxswapRouterMultihop } from "dev-fraxswap/src/contracts/periphery/interfaces/IFraxswapRouterMultihop.sol";
import { IFraxswapRouter } from "dev-fraxswap/src/contracts/periphery/interfaces/IFraxswapRouter.sol";
import { Math } from "dev-fraxswap/src/contracts/core/libraries/Math.sol";
// import { Math as OZMath } from "@openzeppelin/contracts/utils/math/Math.sol";

import { IERC20Metadata as IERC20 } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import { SigUtils } from "src/test/helpers/SigUtils.sol";
import { ERC20Permit } from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";

interface IPairFactory {
    function createPair(address, address) external returns (address);
    function feeToSetter() external view returns (address);
    function setFeeTo(address) external;
    function feeTo() external view returns (address);
    function kLast() external view returns (uint256);
}

contract BaseTest is FraxTest, Constants.Helper {
    // Unpriviledged test users
    uint256 internal testerPrivateKey;
    address payable internal tester;
    address payable internal tester2;
    uint256 internal alicePrivateKey;
    address payable internal alice;
    uint256 internal bobPrivateKey;
    address payable internal bob;
    uint256 internal clairePrivateKey;
    address payable internal claire;
    uint256 internal davePrivateKey;
    address payable internal dave;
    uint256 internal ericPrivateKey;
    address payable internal eric;
    uint256 internal frankPrivateKey;
    address payable internal frank;

    address sigTester;
    uint256 sigPk;
    SigUtils sigUtils;

    address public timelock = Constants.Mainnet.TIMELOCK_ADDRESS;
    address public pairFactory = Constants.Mainnet.PAIR_FACTORY;
    IPairFactory public iPairFactory = IPairFactory(pairFactory);

    // BAMMHelper (@dev: for testing liquidations)
    address public bammHelper;
    BAMMHelper public iBammHelper;
    address public bammUIHelper;
    BAMMUIHelper public iBammUIHelper;

    // BAMMUIHelper (@dev: for FE)
    address public bammUiHelper;
    BAMMUIHelper public iBammUiHelper;

    // BAMMFactory
    address public feeTo = address(0xFEE2);
    address public bammFactory;
    BAMMFactory public iBammFactory;
    address variableInterestRate;
    VariableInterestRate public iVariableInterestRate;

    // BAMM
    address public bamm;
    BAMM public iBamm;

    // BAMMerc20
    address public bammErc20;
    BAMMERC20 public iBammErc20;

    // BAMM Configuration
    address public pair;
    IFraxswapPair public iPair;
    address public routerMultihop = Constants.Mainnet.FRAXSWAP_ROUTER_MULTIHOP;
    IFraxswapRouterMultihop public iRouterMultihop = IFraxswapRouterMultihop(routerMultihop);
    address public oracle;
    FraxswapOracle iBammOracle;

    // Basic v2 router to help add liquidity
    address public router = Constants.Mainnet.FRAXSWAP_ROUTER_V2;
    IFraxswapRouter public iRouter = IFraxswapRouter(router);

    /// @dev These addresses can be modified to test other Frax pools
    address public token0 = Constants.Mainnet.BAMM_TOKEN0;
    IERC20 public iToken0 = IERC20(token0);
    address public token1 = Constants.Mainnet.BAMM_TOKEN1;
    IERC20 public iToken1 = IERC20(token1);

    /// @dev Variable Interest Rate Constants
    uint64 public constant FIFTY_BPS = 158_247_046;
    uint64 public constant DEFAULT_MIN_INTEREST = 158_247_046;
    uint64 public constant DEFAULT_MAX_INTEREST = 146_248_476_607;

    function defaultSetup() internal virtual {
        vm.createSelectFork(vm.envString("MAINNET_RPC_URL"), 17_105_462);

        _initializeAccounts();

        // Deploy the contracts
        // ======================
        (, oracle) = deployFraxswapOracle();
        iBammOracle = FraxswapOracle(oracle);
        (iBammHelper, bammHelper) = deployBammHelper();
        (iBammUIHelper, bammUIHelper) = deployBAMMUIHelper();
        (iVariableInterestRate, variableInterestRate) = deployVariableInterestRate();
        (iBammFactory, bammFactory) = deployBammFactory({
            _fraxswapFactory: pairFactory,
            _routerMultihop: routerMultihop,
            _fraxswapOracle: oracle,
            _variableInterestRate: variableInterestRate,
            _feeTo: feeTo
        });

        // create the BAMM and BAMMERC20

        bamm = iBammFactory.createBamm(pair);
        iBamm = BAMM(bamm);
        iBammErc20 = iBamm.iBammErc20();
        bammErc20 = address(iBammErc20);

        // label addresses
        vm.label(routerMultihop, "RouterMultihop");
        vm.label(router, "Router");
        vm.label(oracle, "FraxswapOracle");
        vm.label(variableInterestRate, "VariableInterestRate");
        vm.label(bamm, "BAMM");
        vm.label(bammFactory, "BAMMFactory");
        vm.label(bammErc20, "BAMMERC20");
        vm.label(tester, "tester");
        vm.label(tester2, "tester2");

        // Set up Alice
        alicePrivateKey = 0xA11CE2;
        alice = payable(vm.addr(alicePrivateKey));
        vm.label(alice, "Alice");

        // Set up Bob
        bobPrivateKey = 0xB0B2;
        bob = payable(vm.addr(bobPrivateKey));
        vm.label(bob, "Bob");

        // Set up Claire
        clairePrivateKey = 0xc0;
        claire = payable(vm.addr(clairePrivateKey));
        vm.label(claire, "Claire");

        // Set up Dave
        davePrivateKey = 0xDa;
        dave = payable(vm.addr(davePrivateKey));
        vm.label(dave, "Dave");

        // Set up Eric
        ericPrivateKey = 0xe0;
        eric = payable(vm.addr(ericPrivateKey));
        vm.label(eric, "Eric");

        // Set up Frank
        frankPrivateKey = 0xf0;
        frank = payable(vm.addr(frankPrivateKey));
        vm.label(frank, "Frank");
    }

    function _initializeAccounts() internal {
        /// @dev: variant of FraxswapRouterLibrary.pairFor() - auto-sorts token0 and token1 if needed
        pairFor(pairFactory, token0, token1);

        // Set up test accounts owning enough to deposit 100% of liquidity
        testerPrivateKey = 0xA11CE;
        tester = payable(vm.addr(testerPrivateKey));
        _mintPctOfReservesToRecipient({ _iPair: iPair, _recipient: tester, _pct: 1e18 });

        testerPrivateKey = 0xB0b;
        tester2 = payable(vm.addr(testerPrivateKey));
        _mintPctOfReservesToRecipient({ _iPair: iPair, _recipient: tester2, _pct: 1e18 });

        // pre-approvals
        vm.startPrank(tester);
        iToken0.approve(router, type(uint256).max);
        iToken1.approve(router, type(uint256).max);
        vm.stopPrank();
        vm.startPrank(tester2);
        iToken0.approve(router, type(uint256).max);
        iToken1.approve(router, type(uint256).max);
        vm.stopPrank();

        // tester and tester2 deposit 10% of supply for LP token (note they have the same pre-existing balances)
        uint256 amount0 = iToken0.balanceOf(tester) / 10;
        uint256 amount1 = iToken1.balanceOf(tester) / 10;
        _addLiquidity({ _from: tester, _amount0Desired: amount0, _amount1Desired: amount1, _to: tester });
        _addLiquidity({ _from: tester2, _amount0Desired: amount0, _amount1Desired: amount1, _to: tester2 });
    }

    function pairFor(address factory, address tokenA, address tokenB) internal {
        (token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        pair = address(
            uint160(
                uint256(
                    keccak256(
                        abi.encodePacked(
                            hex"ff",
                            factory,
                            keccak256(abi.encodePacked(token0, token1)),
                            hex"4ce0b4ab368f39e4bd03ec712dfc405eb5a36cdb0294b3887b441cd1c743ced3" // init code / init hash
                        )
                    )
                )
            )
        );
        iPair = IFraxswapPair(pair);
    }

    /// @notice mint a pct of reserve0, reserve1 to `_recipient`, where 100% = 1e18
    function _mintPctOfReservesToRecipient(IFraxswapPair _iPair, address _recipient, uint256 _pct) internal {
        address t0 = _iPair.token0();
        address t1 = _iPair.token1();
        (uint112 reserve0, uint112 reserve1, ) = _iPair.getReserves();
        deal(t0, _recipient, (reserve0 * _pct) / 1e18);
        deal(t1, _recipient, (reserve1 * _pct) / 1e18);
    }

    function _addLiquidity(
        address _from,
        uint256 _amount0Desired,
        uint256 _amount1Desired,
        address _to
    ) private returns (uint256 amount0, uint256 amount1, uint256 liquidity) {
        vm.prank(_from);
        (amount0, amount1, liquidity) = iRouter.addLiquidity({
            tokenA: token0,
            tokenB: token1,
            amountADesired: _amount0Desired,
            amountBDesired: _amount1Desired,
            amountAMin: 0,
            amountBMin: 0,
            to: _to,
            deadline: block.timestamp + 1
        });
    }

    function _createFreshBamm() internal {
        token0 = address(new ERC20Mock("A", "A"));
        iToken0 = IERC20(token0);
        token1 = address(new ERC20Mock("B", "B"));
        iToken1 = IERC20(token1);

        // mint tokens to testers
        ERC20Mock(address(iToken0)).mint(tester, 1e18);
        ERC20Mock(address(iToken0)).mint(tester2, 1e18);
        ERC20Mock(address(iToken1)).mint(tester, 1e18);
        ERC20Mock(address(iToken1)).mint(tester2, 1e18);

        // create the pair and mint lp to tester
        pair = IPairFactory(pairFactory).createPair(token0, token1);
        iPair = IFraxswapPair(pair);
        ERC20Mock(address(iToken0)).mint(pair, 1e18);
        ERC20Mock(address(iToken1)).mint(pair, 1e18);
        iToken0 = IERC20(iPair.token0());
        iToken1 = IERC20(iPair.token1());
        vm.prank(tester);
        iPair.mint(tester);

        // create bamm contracts for the pair
        bamm = iBammFactory.createBamm(pair);
        iBamm = BAMM(bamm);
        iBammErc20 = iBamm.iBammErc20();
        bammErc20 = address(iBammErc20);

        // Pair might swap token ordering dependent upon address
        iToken0 = iBamm.token0();
        iToken1 = iBamm.token1();
        token0 = address(iToken0);
        token1 = address(iToken1);
    }

    function _initSigs() public {
        sigUtils = new SigUtils(ERC20Permit(address(iToken0)).DOMAIN_SEPARATOR());
        sigPk = 0xFFFFF115;
        sigTester = vm.addr(sigPk);
    }

    //==============================================================================
    // Shares Based Math Helper Functions
    //==============================================================================

    function _calculateLPToBamm(uint256 lpAmt) public returns (uint256) {
        (uint256 resA, uint256 resB, uint256 ts, ) = iBamm.addInterest();
        // Calculate K for the pair
        uint256 sqrtReserve = Math.sqrt(uint256(resA) * resB);
        uint256 bammOut;
        if (iBammErc20.totalSupply() == 0) {
            uint256 sqrtAmount = (lpAmt * sqrtReserve) / ts;
            bammOut = sqrtAmount;
        } else {
            // Calculate % ownership of K owed to `BAMM` via balance of
            // uint256 sqrtBalance = OZMath.mulDiv(iPair.balanceOf(bamm), sqrtReserve, ts, OZMath.Rounding.Expand);
            uint256 sqrtBalance = (iPair.balanceOf(bamm) * sqrtReserve) / ts;
            if ((sqrtBalance * ts) / sqrtReserve < iPair.balanceOf(bamm)) sqrtBalance += 1;
            // Calculate % ownership of K owed to `BAMM` via debt
            uint256 sqrtRentedReal = (uint256(iBamm.sqrtRented()) * iBamm.rentedMultiplier()) / iBamm.PRECISION();
            if ((sqrtRentedReal * iBamm.PRECISION()) / iBamm.rentedMultiplier() < uint256(iBamm.sqrtRented())) {
                sqrtRentedReal += 1;
            }
            // Calculate % ownership of K deposited via lpAdded
            uint256 sqrtAmount = (lpAmt * sqrtReserve) / ts;
            // Shares owed -> sqrtAmt * (total shares / total sqrtAmt Owned by Bamm)
            bammOut = (sqrtAmount * iBammErc20.totalSupply()) / (sqrtBalance + sqrtRentedReal);
        }
        return bammOut;
    }

    function _calculateLpFromRent(uint256 rent, bool roundUp) public returns (uint256) {
        return _calculateLpFromRentWithReserveDelta(rent, 0, 0, roundUp);
    }

    function _calculateLpFromRentWithReserveDelta(
        uint256 rent,
        int256 resADelta,
        int256 resBDelta,
        bool roundUp
    ) public returns (uint256) {
        (uint256 resA, uint256 resB, uint256 ts, ) = iBamm.addInterest();

        /// @dev: default of 0 does not change res0 or res1 - this applies to multi-action executions with an intermediary swap
        resA = resADelta < 0 ? resA - uint256(-resADelta) : resA + uint256(resADelta);
        resB = resBDelta < 0 ? resB - uint256(-resBDelta) : resB + uint256(resBDelta);

        uint256 sqrtAmountRented = (rent * iBamm.rentedMultiplier()) / 1e18;
        if (roundUp) {
            if ((sqrtAmountRented * 1e18) / iBamm.rentedMultiplier() < rent) sqrtAmountRented += 1;
        }
        // Convert to LP
        uint256 lp = (sqrtAmountRented * ts) / uint256(Math.sqrt(uint256(resA) * resB));
        if (roundUp) {
            if ((lp * uint256(Math.sqrt(uint256(resA) * resB))) / ts < sqrtAmountRented) lp += 1;
        }
        return lp;
    }

    function _calculateBammToLP(uint256 bammAmt) public returns (uint256) {
        (uint256 resA, uint256 resB, uint256 ts, ) = iBamm.addInterest();
        // Calculate K for the pair
        uint256 sqrtReserve = Math.sqrt(uint256(resA) * resB);
        // Calculate % ownership of K owed to `BAMM` via balance of
        uint256 sqrtBalance = (iPair.balanceOf(bamm) * sqrtReserve) / ts;
        // Calculate % ownership of K owed to `BAMM` via debt
        uint256 sqrtRentedReal = (uint256(iBamm.sqrtRented()) * iBamm.rentedMultiplier()) / iBamm.PRECISION();
        // Calculate % ownership of K to Withdraw via shares
        uint256 sqrtToRedeem = (bammAmt * (sqrtBalance + sqrtRentedReal)) / iBammErc20.totalSupply();
        // lp owed -> sqrtToRedeem * (TS LP / K)
        uint256 amount = (sqrtToRedeem * ts) / sqrtReserve;
        return amount;
    }

    function _calculateTokensFromLp(uint256 lpAmt, bool roundUp) public returns (uint256, uint256) {
        return _calculateTokensFromLpWithReserveDelta(lpAmt, 0, 0, roundUp);
    }

    function _calculateTokensFromLpWithReserveDelta(
        uint256 lpAmt,
        int256 resADelta,
        int256 resBDelta,
        bool roundUp
    ) public returns (uint256, uint256) {
        (uint256 resA, uint256 resB, uint256 ts, ) = iBamm.addInterest();

        /// @dev: default of 0 does not change res0 or res1 - this applies to multi-action executions with an intermediary swap
        resA = resADelta < 0 ? resA - uint256(-resADelta) : resA + uint256(resADelta);
        resB = resBDelta < 0 ? resB - uint256(-resBDelta) : resB + uint256(resBDelta);

        uint256 token0Amount = (resA * lpAmt) / ts;
        uint256 token1Amount = (resB * lpAmt) / ts;

        /// @dev Used to account for differences in swapPair logic on mint/burn
        if (roundUp) {
            if (((token0Amount * ts) / resA) < lpAmt) {
                token0Amount += 1;
            }
            if (((token1Amount * ts) / resB) < lpAmt) {
                token1Amount += 1;
            }
        }
        return (token0Amount, token1Amount);
    }

    function _calculateSolvency(address _user) public view returns (uint256) {
        (int256 vaultToken0, int256 vaultToken1, int256 rented) = iBamm.userVaults(_user);
        return (uint256(rented) * iBamm.rentedMultiplier()) / Math.sqrt(uint256(vaultToken0 * vaultToken1));
    }

    function turnDexFeeOn(IFraxswapPair _pair) public {
        address fee = address(0xFEE2);
        address factory = _pair.factory();
        IPairFactory iFactory = IPairFactory(factory);
        vm.prank(iFactory.feeToSetter());
        iFactory.setFeeTo(fee);
    }

    function ltv(address user) internal returns (uint256) {
        BAMMUIHelper.BAMMVault memory state = iBammUIHelper.getVaultState(iBamm, user);
        return state.ltv;
    }

    function solvent(address user) internal returns (bool) {
        BAMMUIHelper.BAMMVault memory state = iBammUIHelper.getVaultState(iBamm, user);
        return state.solvent;
    }

    function currentUtilityRate() internal returns (uint256) {
        BAMMUIHelper.BAMMState memory state = iBammUIHelper.getBAMMState(iBamm);
        return state.utilityRate;
    }
}

//==============================================================================
// Erc20AccountStorageSnapshot Functions
//==============================================================================

struct Erc20AccountStorageSnapshot {
    uint256 balanceOf;
    IERC20 token;
}

function calculateDeltaErc20AccountStorageSnapshot(
    Erc20AccountStorageSnapshot memory _start,
    Erc20AccountStorageSnapshot memory _end
) pure returns (Erc20AccountStorageSnapshot memory delta) {
    delta.balanceOf = stdMath.delta(_start.balanceOf, _end.balanceOf);
    // delta.token = _start._address == _end._address ? address(0) : _end._address;
}

//==============================================================================
// Account Storage Snapshot Functions
//==============================================================================

struct AccountStorageSnapshot {
    address bamm;
    address account;
    Erc20AccountStorageSnapshot token0Snapshot;
    Erc20AccountStorageSnapshot token1Snapshot;
    Erc20AccountStorageSnapshot pairSnapshot;
    Erc20AccountStorageSnapshot bammTokenSnapshot;
    uint256 balance;
}

struct DeltaAccountStorageSnapshot {
    AccountStorageSnapshot start;
    AccountStorageSnapshot end;
    AccountStorageSnapshot delta;
}

function accountStorageSnapshot(address _account, address _bamm) view returns (AccountStorageSnapshot memory snapshot) {
    snapshot.account = _account;
    snapshot.bamm = _bamm;
    snapshot.token0Snapshot.token = BAMM(_bamm).token0();
    snapshot.token0Snapshot.balanceOf = snapshot.token0Snapshot.token.balanceOf(_account);
    snapshot.token1Snapshot.token = BAMM(_bamm).token1();
    snapshot.token1Snapshot.balanceOf = snapshot.token1Snapshot.token.balanceOf(_account);
    snapshot.pairSnapshot.token = IERC20(address(BAMM(_bamm).pair()));
    snapshot.pairSnapshot.balanceOf = snapshot.pairSnapshot.token.balanceOf(_account);
    snapshot.bammTokenSnapshot.token = IERC20(address(BAMM(_bamm).iBammErc20()));
    snapshot.bammTokenSnapshot.balanceOf = snapshot.bammTokenSnapshot.token.balanceOf(_account);
    snapshot.balance = _account.balance;
}

function calculateDeltaAccountStorageSnapshot(
    AccountStorageSnapshot memory _start,
    AccountStorageSnapshot memory _end
) pure returns (AccountStorageSnapshot memory delta) {
    delta.account = _start.account == _end.account ? address(0) : _end.account;
    delta.token0Snapshot.balanceOf = stdMath.delta(_start.token0Snapshot.balanceOf, _end.token0Snapshot.balanceOf);
    delta.token1Snapshot.balanceOf = stdMath.delta(_start.token1Snapshot.balanceOf, _end.token1Snapshot.balanceOf);
    delta.bammTokenSnapshot.balanceOf = stdMath.delta(
        _start.bammTokenSnapshot.balanceOf,
        _end.bammTokenSnapshot.balanceOf
    );
    delta.pairSnapshot.balanceOf = stdMath.delta(_start.pairSnapshot.balanceOf, _end.pairSnapshot.balanceOf);
    delta.balance = stdMath.delta(_start.balance, _end.balance);
}

function deltaAccountStorageSnapshot(
    AccountStorageSnapshot memory _start
) view returns (DeltaAccountStorageSnapshot memory delta) {
    delta.start = _start;
    delta.end = accountStorageSnapshot({ _account: _start.account, _bamm: _start.bamm });
    delta.delta = calculateDeltaAccountStorageSnapshot({ _start: delta.start, _end: delta.end });
}

//==============================================================================
// User Snapshot Functions
//==============================================================================

struct UserStorageSnapshot {
    address account;
    BAMM.Vault vault;
    AccountStorageSnapshot accountStorageSnapshot;
}

struct DeltaUserStorageSnapshot {
    UserStorageSnapshot start;
    UserStorageSnapshot end;
    UserStorageSnapshot delta;
}

function userStorageSnapshot(address _account, address _bamm) view returns (UserStorageSnapshot memory snapshot) {
    snapshot.account = _account;
    (int256 token0Amount, int256 token1Amount, int256 rent) = BAMM(_bamm).userVaults(_account);
    snapshot.vault.token0 = token0Amount;
    snapshot.vault.token1 = token1Amount;
    snapshot.vault.rented = rent;
    snapshot.accountStorageSnapshot = accountStorageSnapshot({ _account: _account, _bamm: _bamm });
}

function calculateDeltaUserStorageSnapshot(
    UserStorageSnapshot memory _start,
    UserStorageSnapshot memory _end
) pure returns (UserStorageSnapshot memory delta) {
    delta.vault.token0 = _end.vault.token0 - _start.vault.token0;
    delta.vault.token1 = _end.vault.token1 - _start.vault.token1;
    delta.vault.rented = _end.vault.rented - _start.vault.rented;
    delta.accountStorageSnapshot = calculateDeltaAccountStorageSnapshot({
        _start: _start.accountStorageSnapshot,
        _end: _end.accountStorageSnapshot
    });
}

function deltaUserStorageSnapshot(
    UserStorageSnapshot memory _start
) view returns (DeltaUserStorageSnapshot memory delta) {
    delta.start = _start;
    delta.end = userStorageSnapshot({ _account: _start.account, _bamm: _start.accountStorageSnapshot.bamm });
    delta.delta = calculateDeltaUserStorageSnapshot({ _start: delta.start, _end: delta.end });
}

//==============================================================================
// BAMM Snapshot Functions
//==============================================================================

struct BammStorageSnapshot {
    address bamm;
    int256 sqrtRented;
    uint256 rentedMultiplier;
    uint256 timeSinceLastInterestPayment;
    AccountStorageSnapshot accountStorageSnapshot;
}

struct DeltaBammStorageSnapshot {
    BammStorageSnapshot start;
    BammStorageSnapshot end;
    BammStorageSnapshot delta;
}

function bammStorageSnapshot(address _bamm) view returns (BammStorageSnapshot memory snapshot) {
    snapshot.bamm = _bamm;
    snapshot.sqrtRented = BAMM(_bamm).sqrtRented();
    snapshot.rentedMultiplier = BAMM(_bamm).rentedMultiplier();
    snapshot.timeSinceLastInterestPayment = BAMM(_bamm).timeSinceLastInterestPayment();
    snapshot.accountStorageSnapshot = accountStorageSnapshot({ _account: _bamm, _bamm: _bamm });
}

function calculateDeltaBammStorageSnapshot(
    BammStorageSnapshot memory _start,
    BammStorageSnapshot memory _end
) pure returns (BammStorageSnapshot memory delta) {
    delta.sqrtRented = _end.sqrtRented - _start.sqrtRented;
    delta.rentedMultiplier = _end.rentedMultiplier - _start.rentedMultiplier;
    delta.timeSinceLastInterestPayment = _end.timeSinceLastInterestPayment - _start.timeSinceLastInterestPayment;
    delta.accountStorageSnapshot = calculateDeltaAccountStorageSnapshot({
        _start: _start.accountStorageSnapshot,
        _end: _end.accountStorageSnapshot
    });
}

function deltaBammStorageSnapshot(
    BammStorageSnapshot memory _start
) view returns (DeltaBammStorageSnapshot memory delta) {
    delta.start = _start;
    delta.end = bammStorageSnapshot({ _bamm: _start.bamm });
    delta.delta = calculateDeltaBammStorageSnapshot({ _start: delta.start, _end: delta.end });
}
