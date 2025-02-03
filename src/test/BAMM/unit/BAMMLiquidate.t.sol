// SPDX-License-Identifier: ISC
pragma solidity ^0.8.19;

import "frax-std/FraxTest.sol";
import "../../BaseTest.t.sol";
import "../../../Constants.sol";
import { Math } from "dev-fraxswap/src/contracts/core/libraries/Math.sol";

contract BAMMLiquidateTest is BaseTest {
    IERC20 FRAX = IERC20(0x853d955aCEf822Db058eb8505911ED77F175b99e);
    IERC20 FXS = IERC20(0x3432B6A60D23Ca0dFCa7761B7ab56459D9C964D0);
    address FRAXFXSPool = 0x03B59Bd1c8B9F6C265bA0c3421923B93f15036Fa;

    function setUpEthereum(uint256 _block) public {
        vm.createSelectFork(vm.envString("MAINNET_RPC_URL"), _block);

        _initializeAccounts();
        (iVariableInterestRate, variableInterestRate) = deployVariableInterestRate();

        // Deploy the contracts
        // ======================
        (, oracle) = deployFraxswapOracle();
        (iBammHelper, bammHelper) = deployBammHelper();
        (iBammFactory, bammFactory) = deployBammFactory({
            _fraxswapFactory: pairFactory,
            _routerMultihop: routerMultihop,
            _fraxswapOracle: oracle,
            _variableInterestRate: variableInterestRate,
            _feeTo: feeTo
        });

        // create the BAMM and BAMMERC20
        pair = FRAXFXSPool;
        bamm = iBammFactory.createBamm(FRAXFXSPool);
        iBamm = BAMM(bamm);
        iBammErc20 = iBamm.iBammErc20();
        bammErc20 = address(iBammErc20);
        iBammUIHelper = new BAMMUIHelper();

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

    function test_BAMM_liquidate() public {
        setUpEthereum(18_850_000);
        // Lend Lp tokens
        hoax(Mainnet.AMO_OWNER);
        IERC20(FRAXFXSPool).approve(address(bamm), 95e18);
        hoax(Mainnet.AMO_OWNER);
        BAMM(bamm).mint(address(Mainnet.AMO_OWNER), 95e18);

        // Deposit/rent
        hoax(Mainnet.AMO_OWNER);
        IERC20(FRAX).approve(bamm, 100e18);
        IBAMM.Action memory action = IBAMM.Action(
            0,
            13.865e18,
            95e18,
            address(Mainnet.AMO_OWNER),
            0,
            0,
            false,
            false,
            0,
            0,
            0,
            0
        );
        hoax(Mainnet.AMO_OWNER);
        BAMM(bamm).executeActions(action);

        (int256 token0, int256 token1, int256 rented) = BAMM(bamm).userVaults(Mainnet.AMO_OWNER);
        console.log("Before", uint256(token0), uint256(token1), uint256(rented));

        for (uint256 i = 0; i < 40; ++i) {
            if (i > 3) mineBlocksBySecond(2 * 3600);
            else mineBlocksBySecond(25 * 3600);
            BAMM(bamm).addInterest();
            uint256 _ltv = ltv(Mainnet.AMO_OWNER);
            console.log("ltv      ", _ltv);
            if (_ltv > 0.98e18) {
                hoax(bob);
                BAMM(bamm).microLiquidate(Mainnet.AMO_OWNER);
                _ltv = ltv(Mainnet.AMO_OWNER);
                console.log("ltv after", _ltv);
                console.log("Liquidator", FXS.balanceOf(bob), FRAX.balanceOf(bob));
            }
        }
        (token0, token1, rented) = BAMM(bamm).userVaults(Mainnet.AMO_OWNER);
        console.log("After", uint256(token0), uint256(token1), uint256(rented));
    }

    function test_BAMM_liquidate2() public {
        setUpEthereum(18_850_000);
        // Lend Lp tokens
        hoax(Mainnet.AMO_OWNER);
        IERC20(FRAXFXSPool).approve(address(bamm), 95e18);
        hoax(Mainnet.AMO_OWNER);
        BAMM(bamm).mint(address(Mainnet.AMO_OWNER), 95e18);

        // Deposit/rent
        hoax(Mainnet.AMO_OWNER);
        IERC20(FXS).approve(bamm, 100e18);
        IBAMM.Action memory action = IBAMM.Action(
            1.58e18,
            0,
            95e18,
            address(Mainnet.AMO_OWNER),
            0,
            0,
            false,
            false,
            0,
            0,
            0,
            0
        );
        hoax(Mainnet.AMO_OWNER);
        BAMM(bamm).executeActions(action);

        (int256 token0, int256 token1, int256 rented) = BAMM(bamm).userVaults(Mainnet.AMO_OWNER);
        console.log("Before", uint256(token0), uint256(token1), uint256(rented));

        for (uint256 i = 0; i < 40; ++i) {
            if (i > 3) mineBlocksBySecond(2 * 3600);
            else mineBlocksBySecond(25 * 3600);
            BAMM(bamm).addInterest();
            uint256 _ltv = ltv(Mainnet.AMO_OWNER);
            console.log("ltv      ", _ltv);
            if (_ltv > 0.98e18) {
                hoax(bob);
                BAMM(bamm).microLiquidate(Mainnet.AMO_OWNER);
                _ltv = ltv(Mainnet.AMO_OWNER);
                console.log("ltv after", _ltv);
                console.log("Liquidator", FXS.balanceOf(bob), FRAX.balanceOf(bob));
            }
        }
        (token0, token1, rented) = BAMM(bamm).userVaults(Mainnet.AMO_OWNER);
        console.log("After", uint256(token0), uint256(token1), uint256(rented));
    }

    function test_BAMM_liquidate3() public {
        setUpEthereum(18_850_000);
        // Lend Lp tokens
        hoax(Mainnet.AMO_OWNER);
        IERC20(FRAXFXSPool).approve(address(bamm), 95e18);
        hoax(Mainnet.AMO_OWNER);
        BAMM(bamm).mint(address(Mainnet.AMO_OWNER), 95e18);

        BAMMUIHelper.BAMMState memory state = iBammUIHelper.getBAMMState(BAMM(bamm));

        // Deposit/rent
        hoax(Mainnet.AMO_OWNER);
        IERC20(FXS).approve(bamm, 100e18);
        int256 _token0 = 2.5e18;
        int256 _token1 = -int256((uint256(_token0) * state.reserve1) / (3 * state.reserve0));
        IBAMM.Action memory action = IBAMM.Action(
            _token0,
            _token1,
            95e18,
            address(Mainnet.AMO_OWNER),
            0,
            0,
            false,
            false,
            0,
            0,
            0,
            0
        );
        hoax(Mainnet.AMO_OWNER);
        BAMM(bamm).executeActions(action);

        (int256 token0, int256 token1, int256 rented) = BAMM(bamm).userVaults(Mainnet.AMO_OWNER);
        console.log("Before", uint256(token0), uint256(token1), uint256(rented));

        for (uint256 i = 0; i < 40; ++i) {
            if (i > 3) mineBlocksBySecond(2 * 3600);
            else mineBlocksBySecond(25 * 3600);
            BAMM(bamm).addInterest();
            uint256 _ltv = ltv(Mainnet.AMO_OWNER);
            console.log("ltv      ", _ltv);
            if (_ltv > 0.98e18) {
                hoax(bob);
                BAMM(bamm).microLiquidate(Mainnet.AMO_OWNER);
                _ltv = ltv(Mainnet.AMO_OWNER);
                console.log("ltv after", _ltv);
                console.log("Liquidator", FXS.balanceOf(bob), FRAX.balanceOf(bob));
            }
        }
        (token0, token1, rented) = BAMM(bamm).userVaults(Mainnet.AMO_OWNER);
        console.log("After", uint256(token0), uint256(token1), uint256(rented));
    }

    function test_BAMM_liquidate4() public {
        setUpEthereum(19_968_749);
        mineBlocksBySecond(24 * 60 * 60); // wait 1 day to make sure there are no TWAMMs
        // Lend Lp tokens
        hoax(Mainnet.AMO_OWNER);
        IERC20(FRAXFXSPool).approve(address(bamm), 950e18);
        hoax(Mainnet.AMO_OWNER);
        BAMM(bamm).mint(address(Mainnet.AMO_OWNER), 950e18);

        BAMMUIHelper.BAMMState memory state = iBammUIHelper.getBAMMState(BAMM(bamm));

        // Deposit/rent
        hoax(Mainnet.AMO_OWNER);
        IERC20(FXS).approve(bamm, 1000e18);
        {
            int256 _token0 = 1e18;
            int256 _token1 = -int256((uint256(_token0) * state.reserve1 * 0.6358e18) / (1e18 * state.reserve0));
            int256 _toRent = iBammUIHelper.calcRentForLTV(iBamm, _token0, _token1, int256(0), 0.9749e18);
            _token0 = (_token0 * 900e18) / _toRent;
            _token1 = (_token1 * 900e18) / _toRent;
            _toRent = 900e18;
            IBAMM.Action memory action = IBAMM.Action(
                _token0,
                _token1,
                _toRent,
                address(Mainnet.AMO_OWNER),
                0,
                0,
                false,
                false,
                0,
                0,
                0,
                0
            );
            hoax(Mainnet.AMO_OWNER);
            BAMM(bamm).executeActions(action);
        }

        BAMMUIHelper.BAMMVault memory vault;
        state = iBammUIHelper.getBAMMState(BAMM(bamm));
        console.log("reserve", state.reserve0, state.reserve1);
        {
            (int256 token0, int256 token1, int256 rented) = BAMM(bamm).userVaults(Mainnet.AMO_OWNER);
            console.log("Before", uint256(token0), uint256(token1), uint256(rented));
        }
        uint256 waitedPrev;
        uint256 earnedPrev;
        uint256 earned;
        for (uint256 i = 0; i < 100; ++i) {
            uint256 waited;
            if (i < 3) {
                waited = 25 * 3600;
            } else {
                if (earnedPrev != 0 && earnedPrev < earned) {
                    waited = (5 * (((0.1e18 - earned) * waitedPrev) / (earned - earnedPrev))) / 10;
                } else if (earnedPrev != 0) {
                    waited = 2 * 3600;
                } else if (earned != 0) {
                    waited = 5 * 3600;
                } else {
                    waited = 20 * 3600;
                }
                if (waited < 3600) waited = 1000;
                if (waited > 20 * 3600) waited = 20 * 3600;
                if (i < 20) waited = waited / 2;
                if (i > 50) waited *= 2;
            }
            mineBlocksBySecond(waited);
            //console.log("waited",waited);
            waitedPrev = waited;
            earnedPrev = earned;
            BAMM(bamm).addInterest();
            state = iBammUIHelper.getBAMMState(iBamm);
            vault = iBammUIHelper.getVaultState(iBamm, Mainnet.AMO_OWNER);
            //console.log("vault.ltv",vault.ltv);
            if (vault.ltv > 0.98e18) {
                uint256 liquidationFee = (iBamm.LIQUIDATION_FEE() *
                    (vault.ltv - iBamm.SOLVENCY_THRESHOLD_LIQUIDATION())) /
                    (iBamm.SOLVENCY_THRESHOLD_FULL_LIQUIDATION() - iBamm.SOLVENCY_THRESHOLD_LIQUIDATION());
                uint256 repayPercentage_ = repayPercentage(vault.ltv);
                earned =
                    (2 *
                        ((((uint256(vault.rentedReal) * repayPercentage_) / 1e18) * state.reserve1) /
                            Math.sqrt(state.reserve0 * state.reserve1)) *
                        liquidationFee) /
                    1_000_000;
                //console.log("liquidationFee",liquidationFee);
                //console.log("repayPercentage",repayPercentage);
                //console.log("earned",earned);
                if (earned > 0.1e18) {
                    // 0.1 FRAX
                    //console.log("Liquidator", FXS.balanceOf(bob), FRAX.balanceOf(bob));
                    //console.log("ltv",vault.ltv);
                    console.log("Pre-Full", uint256(vault.token0), uint256(vault.token1), uint256(vault.rentedReal));
                    //console.log("ltv       ",vault.ltv);
                    hoax(bob);
                    BAMM(bamm).microLiquidate(Mainnet.AMO_OWNER);
                    vault = iBammUIHelper.getVaultState(iBamm, Mainnet.AMO_OWNER);
                    console.log("Post-Full", uint256(vault.token0), uint256(vault.token1), uint256(vault.rentedReal));
                    //console.log("Liquidator", FXS.balanceOf(bob), FRAX.balanceOf(bob));
                    earned = 0;
                }
            } else {
                earned = 0;
            }
        }
        vault = iBammUIHelper.getVaultState(iBamm, Mainnet.AMO_OWNER);
        console.log("After", uint256(vault.token0), uint256(vault.token1), uint256(vault.rentedReal));
    }

    function test_BAMM_liquidate5() public {
        setUpEthereum(19_968_749);
        mineBlocksBySecond(24 * 60 * 60); // wait 1 day to make sure there are no TWAMMs
        // Lend Lp tokens
        hoax(Mainnet.AMO_OWNER);
        IERC20(FRAXFXSPool).approve(address(bamm), 9.5e18);
        hoax(Mainnet.AMO_OWNER);
        BAMM(bamm).mint(address(Mainnet.AMO_OWNER), 9.5e18);

        BAMMUIHelper.BAMMState memory state = iBammUIHelper.getBAMMState(BAMM(bamm));

        // Deposit/rent
        hoax(Mainnet.AMO_OWNER);
        IERC20(FXS).approve(bamm, 1000e18);
        {
            int256 _token0 = 1e18;
            int256 _token1 = -int256((uint256(_token0) * state.reserve1 * 0.6358e18) / (1e18 * state.reserve0));
            int256 _toRent = iBammUIHelper.calcRentForLTV(iBamm, _token0, _token1, int256(0), 0.9749e18);
            _token0 = (_token0 * 9e18) / _toRent;
            _token1 = (_token1 * 9e18) / _toRent;
            _toRent = 9e18;
            IBAMM.Action memory action = IBAMM.Action(
                _token0,
                _token1,
                _toRent,
                address(Mainnet.AMO_OWNER),
                0,
                0,
                false,
                false,
                0,
                0,
                0,
                0
            );
            hoax(Mainnet.AMO_OWNER);
            BAMM(bamm).executeActions(action);
        }

        BAMMUIHelper.BAMMVault memory vault;
        state = iBammUIHelper.getBAMMState(BAMM(bamm));
        console.log("reserve", state.reserve0, state.reserve1);
        {
            (int256 token0, int256 token1, int256 rented) = BAMM(bamm).userVaults(Mainnet.AMO_OWNER);
            console.log("Before", uint256(token0), uint256(token1), uint256(rented));
        }
        uint256 waitedPrev;
        uint256 earnedPrev;
        uint256 earned;
        for (uint256 i = 0; i < 100; ++i) {
            uint256 waited;
            if (i < 3) {
                waited = 25 * 3600;
            } else {
                if (earnedPrev != 0 && earnedPrev < earned) {
                    waited = (5 * (((0.1e18 - earned) * waitedPrev) / (earned - earnedPrev))) / 10;
                } else if (earnedPrev != 0) {
                    waited = 2 * 3600;
                } else if (earned != 0) {
                    waited = 5 * 3600;
                } else {
                    waited = 20 * 3600;
                }
                if (waited < 3600) waited = 1000;
                if (waited > 20 * 3600) waited = 20 * 3600;
                if (i < 20) waited = waited / 2;
                if (i > 50) waited *= 2;
            }
            mineBlocksBySecond(waited);
            //console.log("waited",waited);
            waitedPrev = waited;
            earnedPrev = earned;
            BAMM(bamm).addInterest();
            state = iBammUIHelper.getBAMMState(iBamm);
            vault = iBammUIHelper.getVaultState(iBamm, Mainnet.AMO_OWNER);
            //console.log("vault.ltv",vault.ltv);
            if (vault.ltv > 0.98e18) {
                uint256 liquidationFee = (iBamm.LIQUIDATION_FEE() *
                    (vault.ltv - iBamm.SOLVENCY_THRESHOLD_LIQUIDATION())) /
                    (iBamm.SOLVENCY_THRESHOLD_FULL_LIQUIDATION() - iBamm.SOLVENCY_THRESHOLD_LIQUIDATION());
                uint256 repayPercentage_ = repayPercentage(vault.ltv);
                earned =
                    (2 *
                        ((((uint256(vault.rentedReal) * repayPercentage_) / 1e18) * state.reserve1) /
                            Math.sqrt(state.reserve0 * state.reserve1)) *
                        liquidationFee) /
                    1_000_000;
                //console.log("liquidationFee",liquidationFee);
                //console.log("repayPercentage",repayPercentage);
                //console.log("earned",earned);
                if (earned > 0.1e18) {
                    // 0.1 FRAX
                    //console.log("Liquidator", FXS.balanceOf(bob), FRAX.balanceOf(bob));
                    //console.log("ltv",vault.ltv);
                    console.log("Pre-Full", uint256(vault.token0), uint256(vault.token1), uint256(vault.rentedReal));
                    //console.log("ltv       ",vault.ltv);
                    hoax(bob);
                    BAMM(bamm).microLiquidate(Mainnet.AMO_OWNER);
                    vault = iBammUIHelper.getVaultState(iBamm, Mainnet.AMO_OWNER);
                    console.log("Post-Full", uint256(vault.token0), uint256(vault.token1), uint256(vault.rentedReal));
                    //console.log("Liquidator", FXS.balanceOf(bob), FRAX.balanceOf(bob));
                    earned = 0;
                }
            } else {
                earned = 0;
            }
        }
        vault = iBammUIHelper.getVaultState(iBamm, Mainnet.AMO_OWNER);
        console.log("After", uint256(vault.token0), uint256(vault.token1), uint256(vault.rentedReal));
    }

    function test_BAMM_liquidate6() public {
        setUpEthereum(19_968_749);
        mineBlocksBySecond(24 * 60 * 60); // wait 1 day to make sure there are no TWAMMs
        // Lend Lp tokens
        hoax(Mainnet.AMO_OWNER);
        IERC20(FRAXFXSPool).approve(address(bamm), 950e18);
        hoax(Mainnet.AMO_OWNER);
        BAMM(bamm).mint(address(Mainnet.AMO_OWNER), 950e18);

        BAMMUIHelper.BAMMState memory state = iBammUIHelper.getBAMMState(BAMM(bamm));

        // Deposit/rent
        hoax(Mainnet.AMO_OWNER);
        IERC20(FXS).approve(bamm, 1000e18);
        {
            int256 _token0 = 1e18;
            int256 _token1 = -int256((uint256(_token0) * state.reserve1 * 0.6358e18) / (1e18 * state.reserve0));
            int256 _toRent = iBammUIHelper.calcRentForLTV(iBamm, _token0, _token1, int256(0), 0.9749e18);
            _token0 = (_token0 * 900e18) / _toRent;
            _token1 = (_token1 * 900e18) / _toRent;
            _toRent = 900e18;
            IBAMM.Action memory action = IBAMM.Action(
                _token0,
                _token1,
                _toRent,
                address(Mainnet.AMO_OWNER),
                0,
                0,
                false,
                false,
                0,
                0,
                0,
                0
            );
            hoax(Mainnet.AMO_OWNER);
            BAMM(bamm).executeActions(action);
        }

        BAMMUIHelper.BAMMVault memory vault;
        state = iBammUIHelper.getBAMMState(BAMM(bamm));
        console.log("reserve", state.reserve0, state.reserve1);
        {
            (int256 token0, int256 token1, int256 rented) = BAMM(bamm).userVaults(Mainnet.AMO_OWNER);
            console.log("Before", uint256(token0), uint256(token1), uint256(rented));
        }
        uint256 waitedPrev;
        uint256 earnedPrev;
        uint256 earned;
        for (uint256 i = 0; i < 80; ++i) {
            uint256 waited;
            if (i < 3) {
                waited = 25 * 3600;
            } else {
                if (earnedPrev != 0 && earnedPrev < earned) {
                    waited = (5 * (((0.1e18 - earned) * waitedPrev) / (earned - earnedPrev))) / 10;
                } else if (earnedPrev != 0) {
                    waited = 2 * 3600;
                } else if (earned != 0) {
                    waited = 5 * 3600;
                } else {
                    waited = 20 * 3600;
                }
                if (waited < 3600) waited = 1000;
                if (waited > 20 * 3600) waited = 20 * 3600;
                if (i < 20) waited = waited / 2;
                if (i > 50) waited *= 2;
            }
            mineBlocksBySecond(waited);
            //console.log("waited",waited);
            waitedPrev = waited;
            earnedPrev = earned;
            BAMM(bamm).addInterest();
            state = iBammUIHelper.getBAMMState(iBamm);
            vault = iBammUIHelper.getVaultState(iBamm, Mainnet.AMO_OWNER);
            //console.log("vault.ltv",vault.ltv);
            if (vault.ltv > 0.98e18) {
                uint256 liquidationFee = (iBamm.LIQUIDATION_FEE() *
                    (vault.ltv - iBamm.SOLVENCY_THRESHOLD_LIQUIDATION())) /
                    (iBamm.SOLVENCY_THRESHOLD_FULL_LIQUIDATION() - iBamm.SOLVENCY_THRESHOLD_LIQUIDATION());
                uint256 repayPercentage_ = repayPercentage(vault.ltv);
                earned =
                    (2 *
                        ((((uint256(vault.rentedReal) * repayPercentage_) / 1e18) * state.reserve1) /
                            Math.sqrt(state.reserve0 * state.reserve1)) *
                        liquidationFee) /
                    1_000_000;
                //console.log("liquidationFee",liquidationFee);
                //console.log("repayPercentage",repayPercentage);
                //console.log("earned",earned);
                if (earned > 0.0e18) {
                    // 0.0 FRAX
                    //console.log("Liquidator", FXS.balanceOf(bob), FRAX.balanceOf(bob));
                    //console.log("ltv",vault.ltv);
                    console.log("Pre-Full", uint256(vault.token0), uint256(vault.token1), uint256(vault.rentedReal));
                    //console.log("ltv       ",vault.ltv);
                    hoax(bob);
                    BAMM(bamm).microLiquidate(Mainnet.AMO_OWNER);
                    vault = iBammUIHelper.getVaultState(iBamm, Mainnet.AMO_OWNER);
                    console.log("Post-Full", uint256(vault.token0), uint256(vault.token1), uint256(vault.rentedReal));
                    //console.log("Liquidator", FXS.balanceOf(bob), FRAX.balanceOf(bob));
                    earned = 0;
                }
            } else {
                earned = 0;
            }
        }
        vault = iBammUIHelper.getVaultState(iBamm, Mainnet.AMO_OWNER);
        console.log("After", uint256(vault.token0), uint256(vault.token1), uint256(vault.rentedReal));
    }

    function test_BAMM_liquidate_bad_debt() public {
        setUpEthereum(18_850_000);
        // Lend Lp tokens
        hoax(Mainnet.AMO_OWNER);
        IERC20(FRAXFXSPool).approve(address(bamm), 95e18);
        hoax(Mainnet.AMO_OWNER);
        BAMM(bamm).mint(address(Mainnet.AMO_OWNER), 95e18);

        // Deposit/rent
        hoax(Mainnet.AMO_OWNER);
        IERC20(FRAX).approve(bamm, 100e18);
        IBAMM.Action memory action = IBAMM.Action(
            0,
            13.865e18,
            95e18,
            address(Mainnet.AMO_OWNER),
            0,
            0,
            false,
            false,
            0,
            0,
            0,
            0
        );
        hoax(Mainnet.AMO_OWNER);
        BAMM(bamm).executeActions(action);

        (int256 token0, int256 token1, int256 rented) = BAMM(bamm).userVaults(Mainnet.AMO_OWNER);
        console.log("Before", uint256(token0), uint256(token1), uint256(rented));

        for (uint256 i = 0; i < 40; ++i) {
            if (i > 3) mineBlocksBySecond(5 * 3600);
            else mineBlocksBySecond(25 * 3600);
            BAMM(bamm).addInterest();
            uint256 _ltv = ltv(Mainnet.AMO_OWNER);
            (uint256 pps, ) = pricePerShare();
            console.log("ltv      ", _ltv);
            console.log("pps      ", pps);

            if (_ltv > 1.0e18) {
                hoax(bob);
                BAMM(bamm).microLiquidate(Mainnet.AMO_OWNER);
                _ltv = ltv(Mainnet.AMO_OWNER);
                console.log("ltv after", _ltv);
                console.log("Liquidator", FXS.balanceOf(bob), FRAX.balanceOf(bob));
            }
        }
        (token0, token1, rented) = BAMM(bamm).userVaults(Mainnet.AMO_OWNER);
        console.log("After", uint256(token0), uint256(token1), uint256(rented));
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

    function pricePerShare() public returns (uint256 pps, uint256 sqrt) {
        (uint256 reserve0, uint256 reserve1, uint256 pairTotalSupply, ) = iBamm.addInterest();
        uint256 balance = IERC20(pair).balanceOf(bamm);
        uint256 sqrtBalance = _lpTokenToSqrtAmount(balance, pairTotalSupply, reserve0, reserve1);
        uint256 sqrtRentedReal = (uint256(iBamm.sqrtRented()) * iBamm.rentedMultiplier()) / 1e18;
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
}
