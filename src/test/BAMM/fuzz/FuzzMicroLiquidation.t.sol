import "../../BaseTest.t.sol";
import "../../helpers/BAMMTestHelper.sol";
import { FraxswapPair } from "dev-fraxswap/src/contracts/core/FraxswapPair.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract FuzzLiquidateFullTest is BaseTest, BAMMTestHelper {
    address al = address(0xa1);
    address bill = address(0xb111);
    address carl = address(0xca71);
    address gene = address(0xffff292);
    address minter = address(0x77777);

    address liquidator = address(0x117);

    bool weightTkn0;
    uint256 ratio;

    function setUp() public {
        vm.createSelectFork(vm.envString("MAINNET_RPC_URL"));
        defaultSetup();
        _createFreshBamm();
        _mintLP(100e18);
        _lpinBamm(100e18);
    }

    function test_full_liquidation_onCurve_weightedTkn1(uint16 collateralRatio) public {
        setPointOnCollateralCurveRatio(collateralRatio);

        _borrowLp(al, 95e18);

        vm.warp(block.timestamp + 5.5 days);
        _simulateSwapsForOracle(1);

        iBamm.addInterest();
        iBamm.microLiquidate(al);

        assertGt({
            a: iPair.balanceOf(address(iBamm)),
            b: 101e18 // Assert that the lp balance of the bamm is gt initial
        });
    }

    function test_full_liquidation_onCurve_weightedTkn0(uint16 collateralRatio) public {
        weightTkn0 = true;
        setPointOnCollateralCurveRatio(collateralRatio);

        _borrowLp(al, 95e18);

        vm.warp(block.timestamp + 5.5 days);
        _simulateSwapsForOracle(1);

        iBamm.addInterest();
        iBamm.microLiquidate(al);

        assertGt({
            a: iPair.balanceOf(address(iBamm)),
            b: 101e18 // Assert that the LP balance of the bamm is gt initial
        });
    }

    function test_full_liquidation_onCurve_weightedTkn1_sellTkn1(uint16 collateralRatio, uint96 tkn1ToSell) public {
        setPointOnCollateralCurveRatio(collateralRatio);

        _borrowLp(al, 95e18);

        vm.warp(block.timestamp + 5.5 days);

        // Dump the price of the weighted tkn
        if (tkn1ToSell < 1e18) tkn1ToSell = 1e18;
        deal(address(iToken1), carl, tkn1ToSell);
        vm.startPrank(carl);
        uint256 out = iPair.getAmountOut(tkn1ToSell, address(iToken1));
        iToken1.transfer(address(iPair), tkn1ToSell);
        iPair.swap(out, 0, address(carl), hex"");
        vm.stopPrank();

        _simulateSwapsForOracle(1);

        iBamm.addInterest();
        iBamm.microLiquidate(al);

        assertGt({
            a: iPair.balanceOf(address(iBamm)),
            b: 101e18 // Assert that the lp balance of the bamm is gt initial
        });
    }

    function test_full_liquidation_onCurve_weightedTkn0_sellTkn0(uint16 collateralRatio, uint96 tkn0ToSell) public {
        weightTkn0 = true;
        setPointOnCollateralCurveRatio(collateralRatio);

        _borrowLp(al, 95e18);

        vm.warp(block.timestamp + 5.5 days);

        if (tkn0ToSell < 1e18) tkn0ToSell = 1e18;
        deal(address(iToken0), carl, tkn0ToSell);
        vm.startPrank(carl);
        console.log(tkn0ToSell);

        uint256 out = iPair.getAmountOut(tkn0ToSell, address(iToken0));
        console.log("   Out: ", out);
        iToken0.transfer(address(iPair), tkn0ToSell);
        iPair.swap(0, out, address(carl), hex"");
        vm.stopPrank();

        _simulateSwapsForOracle(1);

        iBamm.addInterest();
        iBamm.microLiquidate(al);

        assertGt({
            a: iPair.balanceOf(address(iBamm)),
            b: 101e18 // Assert that the LP balance of the bamm is gt initial
        });
    }

    function test_edge_nominalLP_decreases_rootK_increases() public {
        uint256 bammErc20 = iBammErc20.balanceOf(minter);

        /// @notice rootK In, balance minted as LP given setup function
        uint256 rootIn = (Math.sqrt(100e18 * 100e18) * 1e18) / bammErc20;

        uint8 collateralRatio = 10;
        weightTkn0 = true;
        uint256 tknToDonate = 10_000e18;

        setPointOnCollateralCurveRatio(collateralRatio);

        _borrowLp(al, 95e18);

        vm.warp(block.timestamp + 5.5 days);
        iBamm.addInterest();

        /// @notice Single Sided Donation
        deal(address(iToken0), carl, tknToDonate);
        vm.startPrank(carl);
        console.log(tknToDonate);

        uint256 out = iPair.getAmountOut(tknToDonate, address(iToken0));
        console.log("   Out: ", out);
        iToken0.transfer(address(iPair), tknToDonate);
        iPair.swap(0, 1, address(carl), hex"");
        vm.stopPrank();

        _simulateSwapsForOracle(1);
        iBamm.addInterest();
        iBamm.microLiquidate(al);

        _logLTV(al);

        _log_bamm_and_pair_state();

        (uint256 tkn0Out, uint256 tkn1Out) = _redeemAllBamm();
        uint256 rootOut = (Math.sqrt(tkn0Out * tkn1Out) * 1e18) / bammErc20;

        assertGt(rootOut, rootIn);
    }

    /// Helpers
    function _mintLP(uint256 lp) public {
        uint256 lpBalBefore = iPair.balanceOf(minter);

        uint256 ts = iPair.totalSupply();
        (uint256 token0InPair, uint256 token1InPair, ) = iPair.getReserves();

        uint256 tkn0 = ((lp * token0InPair) / ts);
        uint256 tkn1 = ((lp * token1InPair) / ts);

        deal(address(iToken0), minter, tkn0);
        deal(address(iToken1), minter, tkn1);

        console.log("       ~~ tkn0: ", tkn0);
        console.log("       ~~ tkn1: ", tkn1);

        vm.startPrank(minter);
        iToken0.transfer(address(iPair), tkn0);
        iToken1.transfer(address(iPair), tkn1);
        iPair.mint(minter);
        vm.stopPrank();

        console.log("_mintLP: The balance minted: ", iPair.balanceOf(minter) - lpBalBefore);
    }

    function _lpinBamm(uint256 lpAmount) public {
        uint256 lpBalBefore = iBammErc20.balanceOf(minter);

        vm.startPrank(minter);
        iPair.approve(address(iBamm), lpAmount);
        iBamm.mint(address(minter), lpAmount);
        vm.stopPrank();
        console.log("_lpinBamm: Bamm Minted: ", iBammErc20.balanceOf(minter) - lpBalBefore);
    }

    function setPointOnCollateralCurveRatio(uint16 _ratio) public {
        if (_ratio > 200_000) {
            ratio = 200_000;
        }
        // Only Allow a max ratio of 200000:1
        else {
            ratio = _ratio;
        }

        if (ratio == 0) ratio = 1;
    }

    function _borrowLp(address user, uint256 lpToBorrow) public {
        uint256 ts = iPair.totalSupply();
        (uint256 token0InPair, uint256 token1InPair, ) = iPair.getReserves();

        console.log("       token0InPair: ", token0InPair);
        console.log("       token1InPair: ", token1InPair);
        console.log("       totalSupply: ", ts);

        // solve for rent given lp to borrow
        uint256 rentedReal = (lpToBorrow * Math.sqrt(token0InPair * token1InPair)) / ts;
        uint256 toRent = (rentedReal * 1e18) / iBamm.rentedMultiplier();
        console.log("toRent: ", toRent);
        console.log("rentedReal: ", rentedReal);
        // solve for reserves to borrow make weighted
        uint256 productOnCurve = (((rentedReal * 1000) / 975) ** 2);
        uint256 tkn0;
        uint256 tkn1;
        if (!weightTkn0) {
            tkn0 = Math.sqrt(productOnCurve / ratio);
            tkn1 = ratio * tkn0; // Enforce ratio
        } else {
            tkn1 = Math.sqrt(productOnCurve / ratio); // Enforce ratio
            tkn0 = ratio * tkn1;
        }
        console.log(tkn0, tkn1);

        deal(address(iToken0), user, tkn0);
        deal(address(iToken1), user, tkn1);

        vm.startPrank(user);
        iToken0.approve(address(iBamm), tkn0);
        iToken1.approve(address(iBamm), tkn1);
        BAMM.Action memory action;
        action.token0Amount = int256(tkn0);
        action.token1Amount = int256(tkn1);
        action.rent = int256(toRent);

        iBamm.executeActions(action);

        // Pull excess
        (int256 _tkn0, int256 _tkn1, int256 rented) = iBamm.userVaults(user);
        action.token0Amount = _tkn0 - int256(tkn0);
        action.token1Amount = _tkn1 - int256(tkn1);
        action.token0Amount *= -1;
        action.token1Amount *= -1;
        action.rent = 0;
        iBamm.executeActions(action);
        vm.stopPrank();
    }

    function _simulateSwapsForOracle(uint256 _days) public {
        vm.startPrank(tester);
        (uint256 resA, uint256 resB, ) = iPair.getReserves();
        vm.warp(block.timestamp + _days);
        if (resA < resB) {
            deal(address(iToken0), tester, 0.01e18);
            uint256 out = iPair.getAmountOut(0.01e18, address(iToken0));
            console.log(out);
            iToken0.transfer(address(iPair), 0.01e18);
            iPair.swap(0, out, address(tester), "");
            uint256 _out = iPair.getAmountOut(out, address(iToken1));
            iToken1.transfer(address(iPair), out);
            iPair.swap(_out, 0, address(tester), "");
        } else {
            deal(address(iToken1), tester, 0.01e18);
            uint256 out = iPair.getAmountOut(0.01e18, address(iToken1));
            console.log(out);
            iToken1.transfer(address(iPair), 0.01e18);
            iPair.swap(out, 0, address(tester), "");
            uint256 _out = iPair.getAmountOut(out, address(iToken0));
            iToken0.transfer(address(iPair), out);
            iPair.swap(0, _out, address(tester), "");
        }

        vm.warp(block.timestamp + 31 minutes);
        vm.stopPrank();
    }

    function _logLTV(address user) internal view {
        console.log("\n=============== USER VAULT ===============");
        (int256 tkn0, int256 tkn1, int256 rented) = iBamm.userVaults(user);
        console.log("   tkn0 tkn1: ", uint256(tkn0), uint256(tkn1));
        console.log("       rent: ", uint256(rented));
        console.log("           The rentedMultiplier: ", iBamm.rentedMultiplier());
        if (rented > 0) {
            uint256 ltv = (iBamm.rentedMultiplier() * uint256(rented)) / Math.sqrt(uint256(tkn0 * tkn1));
            console.log("The ltv is: ", ltv);
        }
        console.log("=========================================");
    }

    function _log_bamm_and_pair_state() public {
        uint256 pairTS = iPair.totalSupply();
        (uint256 token0InPair, uint256 token1InPair, ) = iPair.getReserves();
        // uint token0InPair = iToken0.balanceOf(address(iPair));
        // uint token1InPair = iToken1.balanceOf(address(iPair));

        console.log("\n============= FS PAIR STATE =============");
        console.log("The TS of pair: ", pairTS);
        console.log("The token0 in pair: ", token0InPair);
        console.log("The token1 in pair: ", token1InPair);
        console.log(" LP corresponding to 1e18 rented real: ");
        console.log("           ", (pairTS * 1e18) / Math.sqrt(token0InPair * token1InPair));
        console.log("The AMM PRICE in 1e18 (t1 in t0): ", (token0InPair * 1e18) / token1InPair);
        console.log("The AMM PRICE in 1e18 (t0 in t1): ", (token1InPair * 1e18) / token0InPair);
        console.log("\n");

        console.log("============= Bamm State =============");
        console.log("The LP in bamm: ", iPair.balanceOf(bamm));
        console.log("The rentMultiplier Bamm: ", iBamm.rentedMultiplier());
        _logBammUtil(address(iBamm));
    }

    function _logBammUtil(address _bamm) internal view returns (uint256 utilityRate) {
        uint256 balance = BAMM(_bamm).pair().balanceOf(_bamm);
        uint256 ts = BAMM(_bamm).pair().totalSupply();
        (uint256 resA, uint256 resB, ) = BAMM(_bamm).pair().getReserves();
        uint256 sqrtReserves = Math.sqrt(resA * resB);
        {
            uint256 sqrtBalance = (balance * sqrtReserves) / ts;
            uint256 rentedReal = (BAMM(_bamm).rentedMultiplier() * uint256(BAMM(_bamm).sqrtRented())) / 1e18;
            if (sqrtBalance + rentedReal > 0) {
                utilityRate = (rentedReal * 1e18) / (sqrtBalance + rentedReal);
            }
        }
        console.log("The bamm util: ", utilityRate);
    }

    function _redeemAllBamm() public returns (uint256, uint256) {
        uint256 tkn0Pre = iToken0.balanceOf(minter);
        uint256 tkn1Pre = iToken1.balanceOf(minter);

        vm.startPrank(minter);
        uint256 balBamm = iBammErc20.balanceOf(minter);
        iBammErc20.approve(address(iBamm), balBamm);
        iBamm.redeem(minter, balBamm);

        console.log("       LP balance redeemed: ", iPair.balanceOf(minter));

        iPair.transfer(address(iPair), iPair.balanceOf(minter));
        iPair.burn(address(minter));
        uint256 tkn0Balance = iToken0.balanceOf(minter) - tkn0Pre;
        uint256 tkn1Balance = iToken1.balanceOf(minter) - tkn1Pre;
        console.log("tkn0 out: ", tkn0Balance);
        console.log("tkn1 out: ", tkn1Balance);
        return (tkn0Balance, tkn1Balance);
    }
}
