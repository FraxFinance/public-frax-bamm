pragma solidity 0.8.23;

import "../../helpers/BAMMTestHelper.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { FraxswapPair } from "dev-fraxswap/src/contracts/core/FraxswapPair.sol";

contract BAMMFreshTest is BAMMTestHelper {
    using Strings for uint256;

    function setUp() public virtual {
        defaultSetup();
        _createFreshBamm();
    }

    function test_LiquidateAll() public {
        seedAndMintBamm(30_000e18, 31e18);

        BAMM.Action memory action;
        action.token0Amount = 10e18;
        action.rent = 29.24e18;
        iBamm.executeActions(action);

        simulateSwapsForOracle(19.25 days);

        console.log("LTV of the vault: ");
        uint256 ltv = getLTV(tester2);

        assertEq({ a: 0.991134503996887319e18, b: ltv, err: "// THEN: ltv not as expected" });

        vm.startPrank(address(0x21));
        iBamm.microLiquidate(tester2);

        ltv = getLTV(tester2);

        assertEq({ a: 0, b: ltv, err: "// THEN: Vault not closed" });
    }

    function test_LiquidateFee_1percent() public {
        vm.stopPrank();

        hoax(pairFactory);
        FraxswapPair(pair).setFee(100); // 1%

        console.log(iPair.fee());

        test_LiquidateAll();
    }

    function test_slippageIncreasesRepayment() public {
        seedAndMintBamm(31.01e18, 29e18);

        BAMM.Action memory action;
        action.token0Amount = 288.65e18;
        action.token1Amount = -24.995e18;
        action.rent = 27.55e18;
        iBamm.executeActions(action);

        uint256 lpTsStart = iPair.totalSupply();

        simulateSwapsForOracle(4.28 days);
        uint256 ltv = getLTV(tester2);

        (int256 t0, int256 t1, int256 _rentStart) = iBamm.userVaults(tester2);
        (uint256 resA, uint256 resB, ) = iPair.getReserves();

        // TODO: Add Max Sell When other Change comes in

        uint256 sellToken0 = resA / 350;
        uint256 tk1Out = iPair.getAmountOut(sellToken0, address(token0));

        resA += sellToken0;
        resB -= uint256(tk1Out);
        t0 -= int256(sellToken0);
        t1 += int256(tk1Out);

        console.log(repayPercentage(ltv));

        uint256 token1ToLiquidity = (uint256(t1) * repayPercentage(ltv)) / 1e18;
        uint256 sqrtToLiquidity = Math.sqrt(token1ToLiquidity * ((token1ToLiquidity * resA) / resB));
        int256 rentToLiquidity = int256((sqrtToLiquidity * 1e18) / iBamm.rentedMultiplier());

        uint256 lp = _calculateLpFromRent(uint256(rentToLiquidity), true);

        vm.startPrank(address(0x21));
        iBamm.microLiquidate(tester2);

        assertApproxEqAbs({
            a: lp,
            b: iPair.totalSupply() - lpTsStart,
            maxDelta: 0.0015e18,
            err: "// THEN: LP Repayment not in line with expected % repayed"
        });
    }

    function test_rentRoundsDown() public {
        seedAndMintBamm(31.01e18, 1.75e18);

        console.log(iPair.balanceOf(address(bamm)));

        BAMM.Action memory action;
        action.token0Amount = 1e18;
        action.token1Amount = 1e18;
        action.rent = 1e18;

        iBamm.executeActions(action);

        // getLTV(tester2);
        (int256 t0, int256 t1, int256 rent) = iBamm.userVaults(tester2);

        iBamm.addInterest();
        console.log(iBamm.rentedMultiplier());

        // Spike the reserves, do not increase pair TS
        ERC20Mock(address(iToken0)).mint(address(iPair), 300e18);
        ERC20Mock(address(iToken1)).mint(address(iPair), 300e18);
        iPair.sync();

        // Repay one unit
        action.token0Amount = 0;
        action.token1Amount = 0;
        action.rent = -1;

        iBamm.executeActions(action);

        (int256 _t0, int256 _t1, int256 _rent) = iBamm.userVaults(tester2);

        assertGt({ a: rent, b: _rent, err: "// THEN: Rent did not decrease" });

        assertGt({ a: t0, b: _t0, err: "// THEN: Rent decrease did not impact token0" });

        assertGt({ a: t1, b: _t1, err: "// THEN: Rent decrease did not impact token1" });
    }

    function test_rounding_onFees() public {
        seedAndMintBamm(31.01e18, 2.75e18);

        console.log(iBammErc20.totalSupply());
        console.log(iPair.balanceOf(address(bamm)));

        BAMM.Action memory action;
        action.token0Amount = 1e18;
        action.token1Amount = 1e18;
        action.rent = 2e18;

        iBamm.executeActions(action);

        vm.warp(block.timestamp + 365 days);

        uint256 balance = iPair.balanceOf(address(bamm));

        iBamm.addInterest();

        (uint256 reserve0, uint256 reserve1, ) = iPair.getReserves();
        uint256 pairTotalSupply = iPair.totalSupply();
        uint256 sqrtBalance = Math.sqrt(
            ((balance * reserve0) / pairTotalSupply) * ((balance * reserve1) / pairTotalSupply)
        );
        uint256 sqrtRented = uint256(iBamm.sqrtRented());
        uint256 rentM = iBamm.rentedMultiplier();
        uint256 rentedReal = (sqrtRented * rentM) / 1e18;
        uint256 vp = ((sqrtBalance + rentedReal) * 1e18) / iBammErc20.totalSupply();
        console.log(vp);
        console.log(iBammErc20.balanceOf(address(feeTo)));
        console.log(rentM);
        console.log((iBammErc20.balanceOf(address(feeTo)) * 1e18) / iBammErc20.totalSupply());

        uint256 bammFee = iBammErc20.balanceOf(address(feeTo));

        console.log("\n HERE: ");
        console.log(rentedReal - 2e18);
        console.log(bammFee * vp);

        assertApproxEqAbs({
            a: (bammFee * vp * 1e18) / ((rentedReal - 2e18) * 1e18), // bammFeeAs SqrtK / Growth in rented SqrtK
            b: 0.1e18,
            maxDelta: 10,
            err: "// THEN: Fee % not as expected"
        });
    }

    function repayPercentage(uint256 _ltv) internal view returns (uint256 _repayPercentage) {
        uint256 SOLVENCY_THRESHOLD_LIQUIDATION = iBamm.SOLVENCY_THRESHOLD_LIQUIDATION();
        uint256 SOLVENCY_THRESHOLD_FULL_LIQUIDATION = iBamm.SOLVENCY_THRESHOLD_FULL_LIQUIDATION();
        uint256 kink = (SOLVENCY_THRESHOLD_FULL_LIQUIDATION + SOLVENCY_THRESHOLD_LIQUIDATION) / 2;
        uint256 PRECISION = 1e18;
        if (_ltv > SOLVENCY_THRESHOLD_FULL_LIQUIDATION) {
            _repayPercentage = 1e18;
        } else if (_ltv > kink) {
            _repayPercentage = 0.2e18 + (0.8e18 * (_ltv - kink)) / (SOLVENCY_THRESHOLD_FULL_LIQUIDATION - kink);
        } else if (_ltv > SOLVENCY_THRESHOLD_LIQUIDATION) {
            _repayPercentage =
                0.0025e18 +
                (0.1975e18 * (_ltv - SOLVENCY_THRESHOLD_LIQUIDATION)) /
                (kink - SOLVENCY_THRESHOLD_LIQUIDATION);
        } else {
            _repayPercentage = 0;
        }
    }

    function getLTV(address user) public returns (uint256 ltv) {
        iBamm.addInterest();
        (int256 _t0, int256 _t1, int256 _rent) = iBamm.userVaults(user);
        console.log("   ~~~> The vault: ", uint256(_t0), uint256(_t1), uint256(_rent));
        if (Math.sqrt(uint256(_t0 * _t1)) > 0) {
            console.log("   ~~~>", (uint256(_rent) * iBamm.rentedMultiplier()) / Math.sqrt(uint256(_t0 * _t1)));
            ltv = (uint256(_rent) * iBamm.rentedMultiplier()) / Math.sqrt(uint256(_t0 * _t1));
        }
        if (_rent == 0) console.log(" ~~~> Vault Closed");
    }

    function seedAndMintBamm(uint256 lpStart, uint256 lpToMintBamm) public {
        ERC20Mock(address(iToken0)).mint(tester2, 3000e18);
        ERC20Mock(address(iToken1)).mint(tester2, 300e18);
        ERC20Mock(address(iToken0)).mint(tester, 30e18);
        ERC20Mock(address(iToken1)).mint(tester, 30e18);

        ERC20Mock(address(iToken0)).mint(pair, lpStart);
        ERC20Mock(address(iToken1)).mint(pair, lpStart);
        iPair.mint(tester);

        uint256 lpBal = iPair.balanceOf(tester);
        vm.prank(tester);
        iPair.approve(address(iBamm), lpToMintBamm);
        vm.prank(tester);
        iBamm.mint(address(tester), lpToMintBamm);

        console.log("LP Balance: ", lpBal);

        vm.startPrank(tester2);

        iToken0.approve(address(iBamm), 3000e18);
        iToken1.approve(address(iBamm), 300e18);
    }

    function simulateSwapsForOracle(uint256 _days) public {
        vm.warp(block.timestamp + _days);

        uint256 out = iPair.getAmountOut(0.001e18, address(iToken0));
        iToken0.transfer(address(iPair), 0.001e18);
        iPair.swap(0, out, address(tester), "");
        uint256 _out = iPair.getAmountOut(out, address(iToken1));
        iToken1.transfer(address(iPair), out);
        iPair.swap(_out, 0, address(tester), "");

        vm.warp(block.timestamp + 31 minutes);
    }
}
