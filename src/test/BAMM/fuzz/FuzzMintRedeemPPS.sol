// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import "../../BaseTest.t.sol";
import "../../helpers/BAMMTestHelper.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract FuzzMintRedeemPPS is BaseTest, BAMMTestHelper {
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

    function testMintRedeem() public {
        //mintRedeemTest(0, 105768959054 , 0, 0, 0);
        //mintRedeemTest(0, 0, 0, 0, 26328474652440554435318517077548226940336806444168218008271569389);
        //mintRedeemTest(0, 0, 0, 0, 21711009740831560792231838875868807168402529169207472493407850982943054255205);
        //mintRedeemTest(9694, 13249, 1827, 8342, 8122);
        //mintRedeemTest(0, 0, 0, 0, 21711009740831560792231840185575516141563084790845769831136625137753302435581);
        //mintRedeemTest(55, 3749, 29171, 30883789397676964133424023939419148240938386893456966868375756072467545592014, 81972973149137830895603889626239103059924950528100741548763822265790732276709);
        //mintRedeemTest(17469, 4288775752 , 78058887895261563646463867059397571842763086298462167931104639361482561836720 , 7098, 115490685102130217752326921915141221386758781169607488082465057873885209890222);
        //mintRedeemTest(0, 115685608447463930975645380644270879367746217532517195316323218049631479809595, 415505115871464602953691144832037122909355459652979126522594663 , 0, 114887463540149662646824336688307533573166312748180970303685958241273298014379);
        // mintRedeemTest(0, 15448524477906263416270752, 115792089237316195423570985008687907853269984665640564039457584007913129639933, 203207453955255781862758074606640699348303454, 115792089237316195423570985008687907853269984665640564039457584007913129639933);
        // mintRedeemTest(1000000000, 0, 0, 1000000001000002001, 0);
    }

    function test_case1() public {
        testFuzz_mintRedeemTest(0, 0, 0, 0, 0);
    }

    function testFuzz_mintRedeemTest(
        uint256 reserve0,
        uint256 reserve1,
        uint256 mint,
        uint256 redeem,
        uint256 wait
    ) public {
        mintRedeemTest(reserve0, reserve1, mint, redeem, wait);
    }

    struct PpsMath {
        uint256 pps1;
        uint256 pps2;
        uint256 pps3;
        uint256 pps4;
        uint256 pps5;
        uint256 pps6;
    }

    function mintRedeemTest(uint256 reserve0, uint256 reserve1, uint256 mint, uint256 redeem, uint256 wait) public {
        PpsMath memory ppsMath;

        /// Generate parameters
        reserve0 = bound(reserve0, 1_000_000_000, 1e33);
        reserve1 = bound(reserve1, 1_000_000_000, 1e33);
        mint = bound(mint, 0.001e18, 1e18);
        redeem = bound(redeem, 0.001e18, 0.8e18);
        wait = bound(wait, 1, 100 days);
        console.log("reserve0", reserve0);
        console.log("reserve1", reserve1);
        console.log("mint", mint);
        console.log("redeem", redeem);
        console.log("wait", wait);

        {
            // Alice provides liquidity
            deal(token0, pair, reserve0);
            deal(token1, pair, reserve1);
            vm.startPrank(alice);
            IFraxswapPair(pair).mint(alice);
            uint256 balance = IFraxswapPair(pair).balanceOf(alice);
            IFraxswapPair(pair).approve(bamm, balance);
            BAMM(bamm).mint(alice, balance);
            vm.stopPrank();
        }

        int256 rentAmount = int256(((Math.sqrt(reserve0 * reserve1) - 1000) * 85) / 100);
        {
            // Bob add tokens to the vault and rents
            deal(token0, bob, reserve0 * 10);
            deal(token1, bob, reserve1 * 10);
            vm.startPrank(bob);
            IFraxswapPair(token0).approve(bamm, reserve0);
            IFraxswapPair(token1).approve(bamm, reserve1);
            IBAMM.Action memory action = IBAMM.Action(
                int256(reserve0),
                int256(reserve1),
                rentAmount,
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
            BAMM(bamm).executeActions(action);
            vm.stopPrank();
        }
        ppsMath.pps1 = pricePerShare();
        console.log("pps1:", ppsMath.pps1);

        // Wait some time
        mineBlocksBySecond(wait);
        iBamm.addInterest();
        ppsMath.pps2 = pricePerShare();
        console.log("pps2:", ppsMath.pps2);
        {
            // Claire mints
            deal(token0, claire, (reserve0 * mint) / 1e18);
            deal(token1, claire, (reserve1 * mint) / 1e18);
            vm.startPrank(claire);
            IERC20(token0).transfer(pair, (reserve0 * mint) / 1e18);
            IERC20(token1).transfer(pair, (reserve1 * mint) / 1e18);
            IFraxswapPair(pair).mint(claire);
            uint256 balance = IFraxswapPair(pair).balanceOf(claire);
            IFraxswapPair(pair).approve(bamm, balance);
            BAMM(bamm).mint(claire, balance);
            vm.stopPrank();
        }
        ppsMath.pps3 = pricePerShare();
        console.log("pps3:", ppsMath.pps3);
        // Wait some more
        mineBlocksBySecond(wait);
        iBamm.addInterest();
        ppsMath.pps4 = pricePerShare();
        console.log("pps4:", ppsMath.pps4);

        bool bobClosed;
        {
            // Bob closes
            uint256 sqrtRented = uint256(getUserVault(bob).rented) * BAMM(bamm).rentedMultiplier();
            (uint256 _reserve0, uint256 _reserve1, , ) = iBamm.addInterest();
            if (sqrtRented + Math.sqrt(_reserve0 * _reserve1) < 5e33) {
                // Bob might not be able to repay because then the max LP is exceeded.
                vm.startPrank(bob);
                IFraxswapPair(token0).approve(bamm, reserve0 * 10);
                IFraxswapPair(token1).approve(bamm, reserve1 * 10);
                IBAMM.Action memory action = IBAMM.Action(0, 0, 0, bob, 0, 0, true, false, 0, 0, 0, 0);
                BAMM(bamm).executeActions(action);
                vm.stopPrank();
                bobClosed = true;
            }
        }
        ppsMath.pps5 = pricePerShare();
        console.log("pps5:", ppsMath.pps5);
        {
            // Alice redeems
            if (bobClosed) {
                // redeem might fail when bob did not close the position due to high utility
                vm.startPrank(alice);
                uint256 balance = iBammErc20.balanceOf(alice);
                IFraxswapPair(pair).approve(bamm, balance);
                BAMM(bamm).redeem(alice, (balance * redeem) / 1e18);
                vm.stopPrank();
            }
        }
        ppsMath.pps6 = pricePerShare();
        console.log("pps6:", ppsMath.pps6);
        require(ppsMath.pps2 >= ppsMath.pps1, "pps2<pps1");
        require(ppsMath.pps3 >= ppsMath.pps2, "pps3<pps2");
        require(ppsMath.pps4 >= ppsMath.pps3, "pps4<pps3");
        require(ppsMath.pps5 >= ppsMath.pps4, "pps5<pps4");
        require(ppsMath.pps6 >= ppsMath.pps5, "pps6<pps5");
    }

    function pricePerShare() public returns (uint256 pps) {
        (uint256 reserve0, uint256 reserve1, uint256 pairTotalSupply, ) = iBamm.addInterest();
        uint256 balance = IERC20(pair).balanceOf(bamm);
        uint256 sqrtBalance = calcSqrtAmount(balance, pairTotalSupply, reserve0, reserve1);
        uint256 sqrtRentedReal = (uint256(iBamm.sqrtRented()) * iBamm.rentedMultiplier()) / 1e18;
        pps = ((sqrtBalance + sqrtRentedReal) * 1e18) / iBammErc20.totalSupply();
    }

    function calcSqrtAmount(
        uint256 balance,
        uint256 pairTotalSupply,
        uint256 reserve0,
        uint256 reserve1
    ) internal pure returns (uint256 sqrtAmount) {
        uint256 K = reserve0 * reserve1;
        if (K < 2 ** 140) sqrtAmount = Math.sqrt((((K * balance) / pairTotalSupply) * balance) / pairTotalSupply);
        else sqrtAmount = (Math.sqrt(K) * balance) / pairTotalSupply;
    }

    function getUserVault(address user) public view returns (BAMM.Vault memory vault) {
        (vault.token0, vault.token1, vault.rented) = iBamm.userVaults(user);
    }
}
