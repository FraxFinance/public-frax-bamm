// SPDX-License-Identifier: ISC
pragma solidity 0.8.23;

import "frax-std/FraxTest.sol";
import "../../BaseTest.t.sol";
import "../../../Constants.sol";

contract BAMMForkTest is BaseTest {
    function setUpFraxtal(uint256 blockNo) public {
        vm.createSelectFork(vm.envString("FRAXTAL_MAINNET_URL"), blockNo);
        bamm = 0x6B82FCefaD10B27526Dfd2950414CCa768c94fCD;
        iBamm = BAMM(bamm);
        iBammUIHelper = new BAMMUIHelper();
        pair = address(iBamm.pair());
        token0 = IFraxswapPair(pair).token0();
        token1 = IFraxswapPair(pair).token1();
    }

    function test_getChartData1() public {
        setUpFraxtal(7_545_087);
        address user = 0xC6EF452b0de9E95Ccb153c2A5A7a90154aab3419;

        vm.startPrank(user);
        IBAMM.Action memory action = IBAMM.Action(0, 0, -0.02248e18, address(user), 0, 0, false, false, 0, 0, 0, 0);
        BAMM(bamm).executeActions(action);
        vm.stopPrank();

        BAMMUIHelper.ChartPoint[1000] memory points = iBammUIHelper.getChartData0(iBamm, user);
        for (uint256 i = 0; i < 1000; ++i) {
            console.log(uint256(points[i].price), uint256(points[i].value), uint256(points[i].blValue));
        }
    }

    function atest_calcRentForLTV() public {
        setUpFraxtal(7_295_255);
        address user = 0xC6EF452b0de9E95Ccb153c2A5A7a90154aab3419;
        BAMMUIHelper.BAMMState memory state = iBammUIHelper.getBAMMState(iBamm);
        BAMMUIHelper.BAMMVault memory vault = iBammUIHelper.getVaultState(iBamm, user);
        int256 netToken0 = int256(vault.token0 - vault.rentedToken0);
        int256 netToken1 = int256(vault.token1 - vault.rentedToken1);
        console.log(netToken0);
        console.log(netToken1);
        int256 deposit0 = -0.06e18;
        int256 deposit1 = 0;
        int256 toRentReal = iBammUIHelper.calcRentForLTV(
            iBamm,
            netToken0 + deposit0,
            netToken1 + deposit1,
            0,
            0.9749e18
        );
        int256 toRent = (toRentReal * 1e18) / int256(iBamm.rentedMultiplier());
        console.log("toRent", uint256(toRent));
        if (toRent >= 0) {
            IBAMM.Action memory action = IBAMM.Action(
                deposit0,
                deposit1,
                toRent - vault.rented,
                address(user),
                0,
                0,
                false,
                false,
                0,
                0,
                0,
                0
            );
            if (deposit0 > 0) {
                hoax(user);
                IERC20(token0).approve(bamm, uint256(deposit0));
            }
            if (deposit1 > 0) {
                hoax(user);
                IERC20(token1).approve(bamm, uint256(deposit1));
            }
            hoax(user);
            BAMM(bamm).executeActions(action);
            vault = iBammUIHelper.getVaultState(iBamm, user);
            console.log(vault.ltv);
        }
    }

    function atest_liquidate() public {
        setUpFraxtal(7_295_255);
        address user = 0x5B35dBeFb8b4918799246664ed3A7Fe099619814;
        (uint256 token0Fee, uint256 token1Fee) = iBamm.microLiquidate(user);
        console.log(token0Fee, token1Fee);
    }

    function logVault(string memory label, address adr) public view {
        (int256 token0Amount, int256 token1Amount, int256 rented) = BAMM(bamm).userVaults(adr);
        console.log(label, uint256(token0Amount), uint256(token1Amount), uint256(rented));
    }
}
