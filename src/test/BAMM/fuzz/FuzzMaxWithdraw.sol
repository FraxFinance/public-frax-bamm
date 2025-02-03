// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import "../../BaseTest.t.sol";
import "../../helpers/BAMMTestHelper.sol";
import { FraxswapPair } from "dev-fraxswap/src/contracts/core/FraxswapPair.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract FuzzMaxWithdraw is BaseTest, BAMMTestHelper {
    uint256 token0Amount;
    uint256 token1Amount;

    function setUp() public {
        vm.createSelectFork(vm.envString("MAINNET_RPC_URL"), 20_105_462);
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
        bammUIHelper = address(new BAMMUIHelper());

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

    function testmaxWithdraw() public {
        //maxWithdrawTest(214700393070829, 4616223750735476628992285, 3, 50703782867048781, 38787390464505753156105463471523006386332842112235553837838292751593731977052, 46167003017543506446264171998152154684948);
        //maxWithdrawTest(1926054043075919440272182632304507915, 51364013977233747, 92517122406704290286344648335816240485, 3, 115792089237316195423570985008687907853269984665640564039457584007913129639934, 219941125);
        //maxWithdrawTest(0, 35801873288769822190, 1, 115792089237316195423570985008687907853269984665640564039457584007913129639934, 347352226, 294314864036869716242);
        // maxWithdrawTest(75423459751521152605, 10224689545125, 4508, 4720933701559920512426156386600309452471338095064664092374, 3000154575692993359591955722263038720204473738184776281854440216, 290092531974075099513001991905893003467507300921267980);
        // maxWithdrawTest(27368030089, 27731369467445452, 0, 8208473709896181624542480666933703620579549, 2, 57138158229918529125425101625177);
        // maxWithdrawTest(1732781236815054, 1495642876, 104485385125430552227906025180056367940014433287357, 1667043246637435530472878940719, 9713895936068, 284050093212707772465833);
        // maxWithdrawTest(
        //     // reserve 0
        //     30229745946557794096046093133,
        //     // reserve 1
        //     2079647578786366382264983365468,
        //     // vault0
        //     12559814416969320,
        //     // vaullt1
        //     22809055050316150555666228122871270499868102188000017081590387429,
        //     // rent
        //     25708033306199230888343306210739821321914206075679614460090866142540576,
        //     0
        // );
        // maxWithdrawTest(
        //     // reserve 0
        //     30846994302551856749605703253,
        //     // reserve 1
        //     2079647578786366382264983365453,
        //     // vault0
        //     12816267938417045,
        //     // vaullt1
        //     22809055050316150555666228122871270499868102188000017790607282738,
        //     // rent
        //     25457366836869882427757752404798052229435371547559267403198481006917206,
        //     0
        // );
        // maxWithdrawTest(
        //     // reserve 0
        //     60_459_491_893_115_588_192_092_186_125,
        //     // reserve 1
        //     2_079_647_578_786_366_382_264_983_365_481,
        //     // vault0
        //     23_025_119_628_833_938_639,
        //     // vaullt1
        //     22_809_055_050_316_150_555_666_228_122_871_270_499_868_102_188_000_069_148_533_125_497,
        //     // rent
        //     16_021_977_744_341_777_482_697_035_976_355_968_820_442_465_650_555_249_028_174_382_761_672_730,
        //     0
        // );
        // console.log(uint(type(int256).max));
        // maxWithdrawTest(
        //     122871817888885585297, 12957065251817, 3298151604667541640, 32808281384, 0, 1);
    }

    function testFuzz_maxWithdraw(
        uint256 reserve0,
        uint256 reserve1,
        uint256 vault0,
        uint256 vault1,
        uint256 rent,
        uint256 minMax
    ) public {
        maxWithdrawTest(reserve0, reserve1, vault0, vault1, rent, minMax);
    }

    function maxWithdrawTest(
        uint256 reserve0,
        uint256 reserve1,
        uint256 vault0,
        uint256 vault1,
        uint256 rent,
        uint256 withdraw0or1
    ) public {
        /// Generate parameters
        reserve0 = bound(reserve0, 1_000_000_000, 5e33);
        reserve1 = bound(reserve1, 1_000_000_000, 5e33);
        uint256 vault0ratio = bound(vault0, 1, 1e18);
        uint256 vault1ratio = bound(vault1, 1, 1e18);
        rent = bound(rent, 0.0000001e18, 0.899999e18);
        uint256 rentSqrt = (Math.sqrt(reserve0 * reserve1) * rent) / 1e18;
        uint256 rent0 = (reserve0 * rent) / 1e18;
        uint256 rent1 = (reserve1 * rent) / 1e18;
        {
            uint256 collatSqrt = (rentSqrt * 1027) / 1000;
            uint256 vaultSqrt = Math.sqrt(vault0ratio * vault1ratio);
            vault0 = ((vault0ratio * collatSqrt) / vaultSqrt) + 1;
            vault1 = ((vault1ratio * collatSqrt) / vaultSqrt) + 1;
            withdraw0or1 = bound(withdraw0or1, 0, 1);

            console.log("reserve0", reserve0);
            console.log("reserve1", reserve1);
            console.log("rentSqrt", rentSqrt);
            console.log("rent0", rent0);
            console.log("rent1", rent1);
            console.log("collatSqrt", collatSqrt);
            console.log("vault0", vault0);
            console.log("vault1", vault1);
            console.log("withdraw0or1", withdraw0or1);
        }

        if (
            vault0 > 0 &&
            vault0 < 5e33 &&
            vault1 > 0 &&
            vault1 < 5e33 &&
            rentSqrt > 1000 &&
            rent0 > 100_000 &&
            rent1 > 100_000 &&
            reserve0 + vault0 < 5.1e30 &&
            reserve1 + vault1 < 5.1e30 &&
            reserve0 / reserve1 < 1e11 &&
            reserve1 / reserve0 < 1e11
        ) {
            // Alice provides liquidity
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
            {
                // Bob withdraws
                int256 withdraw0;
                int256 withdraw1;
                (int256 _token0, int256 _token1, ) = BAMM(bamm).userVaults(bob);
                withdraw0 = _token0 - int256(vault0);
                withdraw1 = _token1 - int256(vault1);
                action = IBAMM.Action(-withdraw0, -withdraw1, 0, bob, 0, 0, false, false, 0, 0, 0, 0);
            }
            vm.prank(bob);
            BAMM(bamm).executeActions(action);
            logVault("Withdraw", bob);
            {
                console.log("The rent multiplier: ", iBamm.rentedMultiplier());
                BAMMUIHelper.BAMMState memory state = BAMMUIHelper(bammUIHelper).getBAMMState(iBamm);
                BAMMUIHelper.BAMMVault memory vault = BAMMUIHelper(bammUIHelper).getVaultState(iBamm, bob);
                (int256 maxWithdrawToken0, int256 maxWithdrawToken1) = BAMMUIHelper(bammUIHelper).getMaxWithdraw(
                    iBamm,
                    vault.token0,
                    vault.token1,
                    vault.rented
                );
                int256 newNetToken0 = vault.token0 - vault.rentedToken0;
                int256 newNetToken1 = vault.token1 - vault.rentedToken1;
                if (newNetToken0 < int256(state.reserve0 * 100) && newNetToken1 < int256(state.reserve1 * 100)) {
                    if (newNetToken0 / newNetToken1 > 1e6 || newNetToken1 / newNetToken0 > 1e6) {
                        if (newNetToken1 < -maxWithdrawToken1) return;
                        if (newNetToken0 < -maxWithdrawToken0) return;
                    }
                    // ignore extreme cases
                    if (withdraw0or1 == 0) {
                        newNetToken0 += maxWithdrawToken0;
                        int256 calcRent = BAMMUIHelper(bammUIHelper).calcRentForLTV(
                            iBamm,
                            newNetToken0,
                            newNetToken1,
                            0,
                            BAMMUIHelper(bammUIHelper).MAX_WITHDRAW_BAMM_LTV()
                        );
                        if (calcRent >= 0) {
                            int256 toRent = ((calcRent - int256(vault.rentedReal)) *
                                int256(BAMM(bamm).rentedMultiplier())) / 1e18;
                            action = IBAMM.Action(maxWithdrawToken0, 0, toRent, bob, 0, 0, false, false, 0, 0, 0, 0);
                            vm.prank(bob);
                            BAMM(bamm).executeActions(action);
                        }
                    } else {
                        newNetToken1 += maxWithdrawToken1;
                        int256 calcRent = BAMMUIHelper(bammUIHelper).calcRentForLTV(
                            iBamm,
                            newNetToken0,
                            newNetToken1,
                            0,
                            BAMMUIHelper(bammUIHelper).MAX_WITHDRAW_BAMM_LTV()
                        );
                        if (calcRent >= 0) {
                            int256 toRent = ((calcRent - int256(vault.rentedReal)) * 1e18) /
                                int256(BAMM(bamm).rentedMultiplier());
                            action = IBAMM.Action(0, maxWithdrawToken1, toRent, bob, 0, 0, false, false, 0, 0, 0, 0);
                            vm.prank(bob);
                            BAMM(bamm).executeActions(action);
                        }
                    }
                    vault = BAMMUIHelper(bammUIHelper).getVaultState(iBamm, bob);
                    console.log("ltv", vault.ltv);
                    assertApproxEqAbs(
                        vault.ltv,
                        uint256(BAMMUIHelper(bammUIHelper).MAX_WITHDRAW_BAMM_LTV()),
                        10_000_000_000_000
                    );
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
        while (true) {
            ltv = getLTV(user);
            console.log("ltv:", uint256(ltv));
            if (ltv > _targetLtv) break;
            if (_targetLtv - ltv > 0.01e18) mineBlocksBySecond(12 hours);
            else mineBlocksBySecond(3 hours);
            BAMM(bamm).addInterest();
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
