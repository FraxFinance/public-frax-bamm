// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import "../../BaseTest.t.sol";
import "../../helpers/BAMMTestHelper.sol";
import { FraxswapPair } from "dev-fraxswap/src/contracts/core/FraxswapPair.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract FuzzLiquidate2Test is BaseTest, BAMMTestHelper {
    uint256 token0Amount;
    uint256 token1Amount;

    function setUp() public {
        vm.createSelectFork(vm.envString("MAINNET_RPC_URL"), 17_105_462);
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

        // Deploy the contracts
        // ======================
        (, oracle) = deployFraxswapOracle();
        (iBammHelper, bammHelper) = deployBammHelper();
        (iVariableInterestRate, variableInterestRate) = deployVariableInterestRate();
        (iBammFactory, bammFactory) = deployBammFactory({
            _fraxswapFactory: pairFactory,
            _routerMultihop: routerMultihop,
            _fraxswapOracle: oracle,
            _variableInterestRate: variableInterestRate,
            _feeTo: frank
        });

        // create a pair that does not yet exists
        token0 = 0x853d955aCEf822Db058eb8505911ED77F175b99e; //FRAX
        token1 = 0x6B175474E89094C44Da98b954EedeAC495271d0F; //DAI
        pair = IFraxswapFactory(pairFactory).createPair(token0, token1, 30);
        token0 = IFraxswapPair(pair).token0();
        token1 = IFraxswapPair(pair).token1();
        hoax(pairFactory);
        FraxswapPair(pair).setFee(100); // 1%

        // create the BAMM and BAMMERC20

        bamm = iBammFactory.createBamm(pair);
        iBamm = BAMM(bamm);
        iBammErc20 = iBamm.iBammErc20();
        bammErc20 = address(iBammErc20);

        // label addresses
        vm.label(routerMultihop, "RouterMultihop");
        vm.label(router, "Router");
        vm.label(oracle, "FraxswapOracle");
        vm.label(bammHelper, "BAMMHelper");
        vm.label(variableInterestRate, "VariableInterestRate");
        vm.label(bamm, "BAMM");
        vm.label(bammFactory, "BAMMFactory");
        vm.label(bammErc20, "BAMMERC20");
        vm.label(tester, "tester");
        vm.label(tester2, "tester2");
    }

    function testLiquidate() public {
        //liquidateTest(1, 0, 11183219539553036111021792838555153151395689709533409931289, 1036899514070826586766716007227219290332745039913372590912787076934532867, 72895199216, 7871874291375418592501250228758667659033128607739387158767, 32671571285434735871206532781843856168260);
        //liquidateTest(1487238915769137323262637292561931, 41725012086779727114078879625825746310912614231976628703285, 3, 2, 115792089237316195423570985008687907853269984665640564039457584007913129639933, 34679951966017350197783931024055452196752393975166851868078460137287721427933, 1);
    }

    function testFuzz_liquidateTest(
        uint256 reserve0,
        uint256 reserve1,
        uint256 vault0,
        uint256 vault1,
        uint256 rent,
        uint256 withdraw,
        uint256 targetLTV
    ) public {
        liquidateTest(reserve0, reserve1, vault0, vault1, rent, withdraw, targetLTV);
    }

    function liquidateTest(
        uint256 reserve0,
        uint256 reserve1,
        uint256 vault0,
        uint256 vault1,
        uint256 rent,
        uint256 withdraw,
        uint256 targetLTV
    ) public {
        // setUp();

        /// Generate parameters
        reserve0 = bound(reserve0, 1_000_000_000, 5e33);
        reserve1 = bound(reserve1, 1_000_000_000, 5e33);
        uint256 vault0ratio = bound(vault0, 1, 1e18);
        uint256 vault1ratio = bound(vault1, 1, 1e18);
        rent = bound(rent, 0.0000001e18, 0.899999e18);
        uint256 rentSqrt = (Math.sqrt(reserve0 * reserve1) * rent) / 1e18;
        uint256 rent0 = (reserve0 * rent) / 1e18;
        uint256 rent1 = (reserve1 * rent) / 1e18;
        //targetLTV  = 0.9800E18;
        {
            uint256 collatSqrt = (rentSqrt * 1027) / 1000;
            uint256 vaultSqrt = Math.sqrt(vault0ratio * vault1ratio);
            vault0 = ((vault0ratio * collatSqrt) / vaultSqrt) + 1;
            vault1 = ((vault1ratio * collatSqrt) / vaultSqrt) + 1;
            targetLTV = bound(targetLTV, 0.98e18, 1.01e18);

            console.log("reserve0", reserve0);
            console.log("reserve1", reserve1);
            console.log("rentSqrt", rentSqrt);
            console.log("rent0", rent0);
            console.log("rent1", rent1);
            console.log("collatSqrt", collatSqrt);
            console.log("vault0", vault0);
            console.log("vault1", vault1);
            console.log("targetLTV", targetLTV);
        }

        if (
            vault0 > 0 &&
            vault0 < 5e33 &&
            vault1 > 0 &&
            vault1 < 5e33 &&
            rentSqrt > 1000 &&
            reserve0 + vault0 < 5.1e33 &&
            reserve1 + vault1 < 5.1e33
        ) {
            // Alice provides liquidity
            {
                deal(token0, pair, reserve0);
                deal(token1, pair, reserve1);
                IFraxswapPair(pair).mint(alice);
                uint256 balance = IFraxswapPair(pair).balanceOf(alice);
                vm.prank(alice);
                IFraxswapPair(pair).approve(bamm, balance);
                vm.prank(alice);
                BAMM(bamm).mint(alice, balance);
                mineBlocksBySecond(3 days);
                IFraxswapPair(pair).sync();
                mineBlocksBySecond(3 days);
                IFraxswapPair(pair).sync();
            }

            // Bob add tokens to the vault
            deal(token0, bob, vault0);
            deal(token1, bob, vault1);
            vm.prank(bob);
            IFraxswapPair(token0).approve(bamm, vault0);
            vm.prank(bob);
            IFraxswapPair(token1).approve(bamm, vault1);
            IBAMM.Action memory action = IBAMM.Action(
                int256(vault0),
                int256(vault1),
                0,
                bob,
                0,
                0,
                false,
                false,
                0,
                0,
                0,
                0
            );
            vm.prank(bob);
            BAMM(bamm).executeActions(action);
            logVault("Deposit", bob);

            // Bob rents
            action = IBAMM.Action(0, 0, int256(rentSqrt), bob, 0, 0, false, false, 0, 0, 0, 0);
            vm.prank(bob);
            BAMM(bamm).executeActions(action);
            logVault("Rent", bob);
            if (withdraw % 2 == 0) {
                // Bob withdraws
                int256 withdraw0;
                int256 withdraw1;
                (int256 _token0, int256 _token1, ) = BAMM(bamm).userVaults(bob);
                withdraw0 = _token0 - int256(vault0);
                withdraw1 = _token1 - int256(vault1);
                action = IBAMM.Action(-withdraw0, -withdraw1, 0, bob, 0, 0, false, false, 0, 0, 0, 0);
                vm.prank(bob);
                BAMM(bamm).executeActions(action);
                logVault("Withdraw", bob);
            }

            // Lender redeem max liquidity to get max rate
            maxRedeem();
            uint256 ltv = waitInsolvent(bob, targetLTV);

            logVault("Wait", bob);
            {
                (reserve0, reserve1, , ) = iBamm.addInterest();
                console.log("reserve", reserve0, reserve1);
            }

            checkVaults();
            // liquidate
            if (ltv > targetLTV && reserve0 > 10_000 && reserve1 > 10_000) {
                (uint256 pps, uint256 sqrt) = pricePerShare();
                console.log("pps:", pps);
                {
                    uint256 liquidatorToken0Before = IERC20(token0).balanceOf(claire);
                    uint256 liquidatorToken1Before = IERC20(token1).balanceOf(claire);
                    hoax(claire);
                    (uint256 token0Fee, uint256 token1Fee) = BAMM(bamm).microLiquidate(bob);
                    assertEq(liquidatorToken0Before + token0Fee, IERC20(token0).balanceOf(claire));
                    assertEq(liquidatorToken1Before + token1Fee, IERC20(token1).balanceOf(claire));
                }
                logVault("Liquidated", bob);
                logReserve();
                checkVaults();
                (uint256 pps2, uint256 sqrt2) = pricePerShare();
                console.log("pps2:", pps2);
                require(ltv > 0.99e18 || (pps2 >= pps) || sqrt - sqrt2 <= 1, "Bad debt");
                uint256 ltvAfter = getLTVRoundUp(bob);
                console.log("ltv after micro liquidation:", ltvAfter);
                require(ltv > 0.99e18 || ltvAfter <= 0.99e18, "Possible bad debt");
                if (ltv < 0.99e18) {
                    uint256 counter = 0;
                    while (ltvAfter > ltv && counter++ < 3) {
                        hoax(claire);
                        BAMM(bamm).microLiquidate(bob);
                        logVault("Liquidated", bob);
                        logReserve();
                        ltvAfter = getLTVRoundUp(bob);
                    }
                    require(ltvAfter <= ltv, "LTV up");
                }
            }
        }
    }

    function logVault(string memory label, address adr) public view {
        (int256 token0, int256 token1, int256 rented) = BAMM(bamm).userVaults(adr);
        uint256 rentedReal = (uint256(rented) * BAMM(bamm).rentedMultiplier()) / 1e18;
        uint256 ltv = rentedReal == 0 ? 0 : (rentedReal * 1e18) / Math.sqrt(uint256(token0) * uint256(token1));
        console.log(label, uint256(token0), uint256(token1), uint256(rentedReal));
        console.log("ltv", ltv);
    }

    function logReserve() internal {
        (uint256 reserve0, uint256 reserve1, , ) = iBamm.addInterest();
        console.log("reserve", reserve0, reserve1);
    }

    function maxRedeem() public {
        // Lender redeem max liquidity to get max rate
        uint256 balance = IERC20(pair).balanceOf(bamm);
        (uint256 reserve0, uint256 reserve1, uint256 pairTotalSupply, ) = iBamm.addInterest();
        uint256 sqrtBalance = Math.sqrt(
            ((balance * reserve0) / pairTotalSupply) * ((balance * reserve1) / pairTotalSupply)
        );
        uint256 sqrtRentedReal = (uint256(iBamm.sqrtRented()) * iBamm.rentedMultiplier()) / 1e18;
        console.log("sqrtBalance", sqrtBalance);
        console.log("sqrtRentedReal", sqrtRentedReal);
        console.log("iBammErc20.totalSupply()", iBammErc20.totalSupply());
        if (sqrtBalance > ((sqrtRentedReal * 10) / 86)) {
            uint256 redeemAmount = ((sqrtBalance - ((sqrtRentedReal * 10) / 86)) * iBammErc20.totalSupply()) /
                (sqrtBalance + sqrtRentedReal);
            if (redeemAmount > iBammErc20.balanceOf(alice)) redeemAmount = iBammErc20.balanceOf(alice);
            hoax(alice);
            BAMM(bamm).redeem(address(alice), redeemAmount);
            uint256 pairBalance = IFraxswapPair(pair).balanceOf(alice);
            hoax(alice);
            IFraxswapPair(pair).transfer(pair, pairBalance);
            IFraxswapPair(pair).burn(alice);
        }
    }

    function getLTV(address user) public returns (uint256 ltv) {
        (int256 token0, int256 token1, int256 rented) = BAMM(bamm).userVaults(user);
        rented = (rented * int256(BAMM(bamm).rentedMultiplier())) / 1e18;
        if (token0 > 0 && token1 > 0) ltv = (uint256(rented) * 1e18) / Math.sqrt(uint256(token0 * token1));
    }

    // LTV calcualtion with 2 tokens added to each side, to avoid failing on a higher LTV due to rounding.
    function getLTVRoundUp(address user) public returns (uint256 ltv) {
        (int256 token0, int256 token1, int256 rented) = BAMM(bamm).userVaults(user);
        rented = (rented * int256(BAMM(bamm).rentedMultiplier())) / 1e18;
        if (token0 > 0 && token1 > 0) ltv = (uint256(rented) * 1e18) / Math.sqrt(uint256((token0 + 2) * (token1 + 2)));
    }

    function waitInsolvent(address user, uint256 _targetLtv) public returns (uint256 ltv) {
        uint256 prevLTV;
        while (true) {
            ltv = getLTV(user);
            console.log("ltv:", uint256(ltv));
            if (ltv > _targetLtv) break;
            if (ltv == prevLTV) break;
            if (_targetLtv - ltv > 1e18) mineBlocksBySecond(48 hours);
            else if (_targetLtv - ltv > 0.1e18) mineBlocksBySecond(6 hours);
            else if (_targetLtv - ltv > 0.01e18) mineBlocksBySecond(20 minutes);
            else if (_targetLtv - ltv > 0.001e18) mineBlocksBySecond(10 minutes);
            else mineBlocksBySecond(120);
            BAMM(bamm).addInterest();
            prevLTV = ltv;
        }
    }

    function pricePerShare() public returns (uint256 pps, uint256 sqrt) {
        (uint256 reserve0, uint256 reserve1, uint256 pairTotalSupply, ) = iBamm.addInterest();
        uint256 balance = IERC20(pair).balanceOf(bamm);
        uint256 sqrtBalance = _lpTokenToSqrtAmount(balance, pairTotalSupply, reserve0, reserve1);
        uint256 sqrtRentedReal = (uint256(iBamm.sqrtRented()) * iBamm.rentedMultiplier()) / 1e18;
        console.log("sqrtBalance", sqrtBalance);
        console.log("sqrtRentedReal", sqrtRentedReal);
        console.log("totalSupply", iBammErc20.totalSupply());
        sqrt = sqrtBalance + sqrtRentedReal;
        pps = ((sqrt) * 1e18) / iBammErc20.totalSupply();
    }

    function _lpTokenToSqrtAmount(
        uint256 lpTokens,
        uint256 pairTotalSupply,
        uint256 reserve0,
        uint256 reserve1
    ) internal pure returns (uint256 sqrtAmount) {
        uint256 K = reserve0 * reserve1;
        if (K < 2 ** 140) sqrtAmount = Math.sqrt((((K * lpTokens) / pairTotalSupply) * lpTokens) / pairTotalSupply);
        else sqrtAmount = (Math.sqrt(K) * lpTokens) / pairTotalSupply;
    }

    function checkVaults() public {
        BAMM.Vault memory vault = getUserVault(bob);
        assertEq(uint256(vault.token0), IERC20(token0).balanceOf(bamm));
        assertEq(uint256(vault.token1), IERC20(token1).balanceOf(bamm));
        assertEq(uint256(vault.rented), uint256(iBamm.sqrtRented()));
    }

    function getUserVault(address user) public view returns (BAMM.Vault memory vault) {
        (vault.token0, vault.token1, vault.rented) = iBamm.userVaults(user);
    }
}
