// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import "../../BaseTest.t.sol";
import "../../helpers/BAMMTestHelper.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract FuzzRentRepayPPS is BaseTest, BAMMTestHelper {
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

    function testRentRepay() public {
        //rentRepayTest(0, 105768959054 , 0, 0, 0);
        //rentRepayTest(0, 89261494603165740002342043132945458368845727106017492862060120914122874499284, 0, 0, 4957520697273816929869133306835200003683989963790159576547123687033051219);
        //rentRepayTest(0, 0, 0, 0, 21344314024794689648119433252036678100338197954500865816571964132825659598715);
        //rentRepayTest(4, 0, 0, 1000000000000000, 27013879532169406533361597362);
        //rentRepayTest(0, 4, 0, 115792089237309613405341508622576679729543424728445391399453370124291096586932, 115792089237316195423570985008687907853269984665640564039457584007913129639933);
        //rentRepayTest(0, 0, 0, 0, 1395612492111613237891668084295153120949585670602623678581392800437877518717);
    }

    function testFuzz_rentRepayTest(
        uint256 reserve0,
        uint256 reserve1,
        uint256 rent,
        uint256 repay,
        uint256 wait
    ) public {
        rentRepayTest(reserve0, reserve1, rent, repay, wait);
    }

    function rentRepayTest(uint256 reserve0, uint256 reserve1, uint256 rent, uint256 repay, uint256 wait) public {
        // setUp();

        /// Generate parameters
        reserve0 = bound(reserve0, 1_000_000_000, 2e33);
        reserve1 = bound(reserve1, 1_000_000_000, 2e33);
        rent = bound(rent, 0.001e18, 1e18);
        repay = bound(repay, 0.001e18, 1e18);
        wait = bound(wait, 1, 100 days);
        console.log("reserve0", reserve0);
        console.log("reserve1", reserve1);
        console.log("rent", rent);
        console.log("repay", repay);
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

        uint256 pps1 = pricePerShare();
        console.log("pps1:", pps1);

        int256 rentAmount = int256((Math.sqrt(reserve0 * reserve1) * 88) / 100);
        int256 repayAmount = (rentAmount * int256(repay)) / 1e18;
        {
            // Bob add tokens to the vault and rents
            deal(token0, bob, reserve0 * 10);
            deal(token1, bob, reserve1 * 10);
            vm.startPrank(bob);
            IFraxswapPair(token0).approve(bamm, reserve0 * 10);
            IFraxswapPair(token1).approve(bamm, reserve1 * 10);
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

        // Wait some time
        mineBlocksBySecond(wait);
        iBamm.addInterest();
        uint256 pps2 = pricePerShare();
        console.log("pps2:", pps2);

        {
            // Bob repays
            (uint256 _reserve0, uint256 _reserve1, , ) = iBamm.addInterest();
            if (uint256(repayAmount) * BAMM(bamm).rentedMultiplier() + Math.sqrt(_reserve0 * _reserve1) < 5e33) {
                // Bob might not be able to repay because then the max LP is exceeded.
                vm.startPrank(bob);
                IBAMM.Action memory action = IBAMM.Action(
                    int256(reserve0),
                    int256(reserve1),
                    -repayAmount,
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
        }
        uint256 pps3 = pricePerShare();
        console.log("pps3:", pps3);
        // Wait some more
        mineBlocksBySecond(wait);
        iBamm.addInterest();
        uint256 pps4 = pricePerShare();
        console.log("pps4:", pps4);
        {
            // Bob closes
            uint256 sqrtRented = uint256(getUserVault(bob).rented) * BAMM(bamm).rentedMultiplier();
            (uint256 _reserve0, uint256 _reserve1, , ) = iBamm.addInterest();
            if (sqrtRented + Math.sqrt(_reserve0 * _reserve1) < 5e33) {
                // Bob might not be able to repay because then the max LP is exceeded.
                vm.startPrank(bob);
                IBAMM.Action memory action = IBAMM.Action(0, 0, 0, bob, 0, 0, true, false, 0, 0, 0, 0);
                BAMM(bamm).executeActions(action);
                vm.stopPrank();
            }
        }
        uint256 pps5 = pricePerShare();
        console.log("pps5:", pps5);
        require(pps2 >= pps1, "pps2<pps1");
        require(pps3 >= pps2, "pps3<pps2");
        require(pps4 >= pps3, "pps4<pps3");
        require(pps5 >= pps4, "pps5<pps4");
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
