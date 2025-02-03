// SPDX-License-Identifier: ISC
pragma solidity 0.8.23;

import "frax-std/FraxTest.sol";
import "../../BaseTest.t.sol";
import "../../../Constants.sol";

contract BAMMEventTest is BaseTest {
    IERC20 FRAX = IERC20(0x853d955aCEf822Db058eb8505911ED77F175b99e);
    IERC20 FXS = IERC20(0x3432B6A60D23Ca0dFCa7761B7ab56459D9C964D0);
    address FRAXFXSPool = 0x03B59Bd1c8B9F6C265bA0c3421923B93f15036Fa;
    address whale = 0xB1748C79709f4Ba2Dd82834B8c82D4a505003f27;

    function setUpEthereum(uint256 blockNo) public {
        vm.createSelectFork(vm.envString("MAINNET_RPC_URL"), blockNo);
        iRouterMultihop = IFraxswapRouterMultihop(payable(0x25e9acA5951262241290841b6f863d59D37DC4f0));

        _initializeAccounts();

        // Deploy the contracts
        // ======================
        (, oracle) = deployFraxswapOracle();
        (iBammHelper, bammHelper) = deployBammHelper();
        (iBammUIHelper, bammUIHelper) = deployBAMMUIHelper();
        (iVariableInterestRate, variableInterestRate) = deployVariableInterestRate();
        (iBammFactory, bammFactory) = deployBammFactory({
            _fraxswapFactory: pairFactory,
            _routerMultihop: routerMultihop,
            _fraxswapOracle: oracle,
            _variableInterestRate: variableInterestRate,
            _feeTo: address(0)
        });

        // create the BAMM and BAMMERC20
        (iVariableInterestRate, variableInterestRate) = deployVariableInterestRate();
        bamm = iBammFactory.createBamm(FRAXFXSPool);
        iBamm = BAMM(bamm);
        iBammErc20 = iBamm.iBammErc20();
        bammErc20 = address(iBammErc20);
        pair = address(iBamm.pair());

        // Set up Alice
        alicePrivateKey = 0xA11CE2;
        alice = payable(vm.addr(alicePrivateKey));
        vm.label(alice, "Alice");

        // Set up Bob
        bobPrivateKey = 0xB0B2;
        bob = payable(vm.addr(bobPrivateKey));
        vm.label(bob, "Bob");
    }

    function test_events() public {
        setUpEthereum(20_376_600);
        {
            // mint
            vm.startPrank(Mainnet.AMO_OWNER);
            uint256 lpIn = 100e18;
            IERC20(FRAXFXSPool).approve(address(bamm), 100e18);
            (uint256 reserve0, uint256 reserve1, uint256 pairTotalSupply, uint256 _rentedMultiplier) = BAMM(bamm)
                .addInterest();
            uint256 sqrtReserve = Math.sqrt(uint256(reserve0) * reserve1);
            uint256 sqrtAmount = (lpIn * sqrtReserve) / pairTotalSupply;
            vm.expectEmit(true, true, true, true, bamm);
            emit IBAMM.BAMMMinted(Mainnet.AMO_OWNER, Mainnet.AMO_OWNER, 100e18, sqrtAmount - iBamm.MINIMUM_LIQUIDITY());
            BAMM(bamm).mint(address(Mainnet.AMO_OWNER), lpIn);
            vm.stopPrank();
        }
        {
            // redeem
            vm.startPrank(Mainnet.AMO_OWNER);
            uint256 bammIn = 50e18;
            uint256 balance = IFraxswapPair(pair).balanceOf(bamm);
            uint256 lpOut = (balance * bammIn) / iBammErc20.totalSupply();
            (uint256 reserve0, uint256 reserve1, uint256 pairTotalSupply, uint256 _rentedMultiplier) = BAMM(bamm)
                .addInterest();
            uint256 sqrtReserve = Math.sqrt(uint256(reserve0) * reserve1);
            uint256 sqrtBalance = (((balance - lpOut) * sqrtReserve) / pairTotalSupply);
            uint256 _utilization = 0;
            uint256 utilScaled = (_utilization * 1e5) / BAMM(bamm).MAX_UTILITY_RATE();
            (uint256 newRatePerSec, ) = BAMM(bamm).variableInterestRate().getNewRate(
                0,
                utilScaled,
                uint64(BAMM(bamm).fullUtilizationRate())
            );

            vm.expectEmit(true, true, true, true, bamm);
            emit IBAMM.BAMMRedeemed(Mainnet.AMO_OWNER, Mainnet.AMO_OWNER, bammIn, lpOut);
            vm.expectEmit(true, true, true, true, bamm);
            emit IBAMM.BAMMState(0, sqrtBalance, _rentedMultiplier, newRatePerSec);
            BAMM(bamm).redeem(address(Mainnet.AMO_OWNER), bammIn);
            vm.stopPrank();
        }
        {
            // deposit 0
            vm.startPrank(whale);
            FXS.approve(bamm, 100e18);
            vm.expectEmit(true, true, true, true, bamm);
            emit IBAMM.ExecuteAction(whale, 1e18, 0, 0);
            vm.expectEmit(true, true, true, true, bamm);
            emit IBAMM.VaultUpdated(whale, 1e18, 0, 0);
            IBAMM.Action memory action = IBAMM.Action(1e18, 0, 0, address(whale), 0, 0, false, false, 0, 0, 0, 0);
            BAMM(bamm).executeActions(action);
            vm.stopPrank();
        }
        {
            // deposit 1
            vm.startPrank(whale);
            FRAX.approve(bamm, 100e18);
            vm.expectEmit(true, true, true, true, bamm);
            emit IBAMM.ExecuteAction(whale, 0, 1e18, 0);
            vm.expectEmit(true, true, true, true, bamm);
            emit IBAMM.VaultUpdated(whale, 1e18, 1e18, 0);
            IBAMM.Action memory action = IBAMM.Action(0, 1e18, 0, address(whale), 0, 0, false, false, 0, 0, 0, 0);
            BAMM(bamm).executeActions(action);
            vm.stopPrank();
        }
        {
            // rent
            vm.startPrank(whale);
            (uint256 reserve0, uint256 reserve1, uint256 pairTotalSupply, uint256 _rentedMultiplier) = BAMM(bamm)
                .addInterest();
            uint256 sqrtReserve = Math.sqrt(uint256(reserve0) * reserve1);
            int256 rented = 1e18;
            int256 rentedReal = (rented * int256(_rentedMultiplier)) / 1e18;
            int256 token0Rented = ((rentedReal * int256(reserve0)) / int256(sqrtReserve)) - 1;
            int256 token1Rented = ((rentedReal * int256(reserve1)) / int256(sqrtReserve)) - 1;
            uint256 lpOut = (uint256(rentedReal) * pairTotalSupply) / sqrtReserve;
            uint256 sqrtBalance = (((IFraxswapPair(pair).balanceOf(bamm) - lpOut) * sqrtReserve) / pairTotalSupply);
            uint256 _utilization = (uint256(rentedReal) * 1e18) / (uint256(rentedReal) + sqrtBalance);
            uint256 utilScaled = (_utilization * 1e5) / BAMM(bamm).MAX_UTILITY_RATE();
            (uint256 newRatePerSec, ) = BAMM(bamm).variableInterestRate().getNewRate(
                0,
                utilScaled,
                uint64(BAMM(bamm).fullUtilizationRate())
            );
            vm.expectEmit(true, true, true, true, bamm);
            emit IBAMM.Renting(whale, rented, token0Rented, token1Rented);
            vm.expectEmit(true, true, true, true, bamm);
            emit IBAMM.ExecuteAction(whale, 0, 0, rented);
            vm.expectEmit(true, true, true, true, bamm);
            emit IBAMM.VaultUpdated(whale, 1e18 + token0Rented, 1e18 + token1Rented, rented);
            vm.expectEmit(true, true, true, true, bamm);
            emit IBAMM.BAMMState(uint256(rentedReal), sqrtBalance, _rentedMultiplier, newRatePerSec);
            IBAMM.Action memory action = IBAMM.Action(0, 0, rented, address(whale), 0, 0, false, false, 0, 0, 0, 0);
            BAMM(bamm).executeActions(action);
            vm.stopPrank();
        }
        {
            // repay
            (int256 t0, int256 t1, ) = iBamm.userVaults(whale);
            vm.startPrank(whale);
            (uint256 reserve0, uint256 reserve1, uint256 pairTotalSupply, uint256 _rentedMultiplier) = BAMM(bamm)
                .addInterest();
            uint256 sqrtReserve = Math.sqrt(uint256(reserve0) * reserve1);
            int256 rented = 0.5e18;
            int256 rentedReal = (rented * int256(_rentedMultiplier)) / 1e18;
            if ((1e18 * rentedReal) / int256(_rentedMultiplier) < rentedReal) rentedReal += 1;
            uint256 lpOut = ((uint256(rentedReal) * pairTotalSupply) / sqrtReserve);
            if ((sqrtReserve * lpOut) / pairTotalSupply < uint256(rentedReal)) lpOut += 1;
            int256 token0Rented = ((int256(lpOut) * int256(reserve0)) / int256(pairTotalSupply));
            if ((uint256(token0Rented) * pairTotalSupply) / reserve0 < lpOut) token0Rented += 1;
            int256 token1Rented = ((int256(lpOut) * int256(reserve1)) / int256(pairTotalSupply));
            if ((uint256(token1Rented) * pairTotalSupply) / reserve1 < lpOut) token1Rented += 1;

            vm.expectEmit(true, true, true, true, bamm);
            emit IBAMM.RentRepaid(whale, rented, uint256(token0Rented), uint256(token1Rented), false);
            vm.expectEmit(true, true, true, true, bamm);
            emit IBAMM.ExecuteAction(whale, 0, 0, -rented);
            vm.expectEmit(true, true, true, true, bamm);
            emit IBAMM.VaultUpdated(whale, t0 - token0Rented, t1 - token1Rented, rented);
            IBAMM.Action memory action = IBAMM.Action(0, 0, -rented, address(whale), 0, 0, false, false, 0, 0, 0, 0);
            BAMM(bamm).executeActions(action);
            vm.stopPrank();
        }
        {
            // close
            (int256 t0, int256 t1, ) = iBamm.userVaults(whale);
            vm.startPrank(whale);
            (uint256 reserve0, uint256 reserve1, uint256 pairTotalSupply, uint256 _rentedMultiplier) = BAMM(bamm)
                .addInterest();
            uint256 sqrtReserve = Math.sqrt(uint256(reserve0) * reserve1);
            int256 rented = 0.5e18;
            int256 rentedReal = (rented * int256(_rentedMultiplier)) / 1e18;
            if ((1e18 * rentedReal) / int256(_rentedMultiplier) < rentedReal) rentedReal += 1;
            uint256 lpOut = ((uint256(rentedReal) * pairTotalSupply) / sqrtReserve);
            if ((sqrtReserve * lpOut) / pairTotalSupply < uint256(rentedReal)) lpOut += 1;
            int256 token0Rented = ((int256(lpOut) * int256(reserve0)) / int256(pairTotalSupply));
            if ((uint256(token0Rented) * pairTotalSupply) / reserve0 < lpOut) token0Rented += 1;
            int256 token1Rented = ((int256(lpOut) * int256(reserve1)) / int256(pairTotalSupply));
            if ((uint256(token1Rented) * pairTotalSupply) / reserve1 < lpOut) token1Rented += 1;
            vm.expectEmit(true, true, true, true, bamm);
            emit IBAMM.RentRepaid(whale, rented, uint256(token0Rented), uint256(token1Rented), true);
            vm.expectEmit(true, true, true, true, bamm);
            emit IBAMM.ExecuteAction(whale, -(t0 - token0Rented), -(t1 - token1Rented), -rented);
            vm.expectEmit(true, true, true, true, bamm);
            emit IBAMM.VaultUpdated(whale, 0, 0, 0);
            IBAMM.Action memory action = IBAMM.Action(0, 0, 0, address(whale), 0, 0, true, false, 0, 0, 0, 0);
            BAMM(bamm).executeActions(action);
            vm.stopPrank();
        }
    }

    function test_swap_events() public {
        setUpEthereum(20_376_600);
        {
            // mint
            vm.startPrank(Mainnet.AMO_OWNER);
            IERC20(FRAXFXSPool).approve(address(bamm), 100e18);
            BAMM(bamm).mint(address(Mainnet.AMO_OWNER), 100e18);
            vm.stopPrank();
        }
        {
            // deposit
            vm.startPrank(whale);
            FRAX.approve(bamm, 100e18);
            IBAMM.Action memory action = IBAMM.Action(0, 1e18, 0, address(whale), 0, 0, false, false, 0, 0, 0, 0);
            vm.expectEmit(true, true, true, true, bamm);
            emit IBAMM.VaultUpdated(whale, 0, 1e18, 0);
            BAMM(bamm).executeActions(action);
            vm.stopPrank();
        }
        {
            // swap
            vm.startPrank(whale);
            uint256 amountOut = IFraxswapPair(FRAXFXSPool).getAmountOut(1e18, address(FRAX));
            IBAMM.Action memory action = IBAMM.Action(0, 0, 0, address(whale), 0, 0, false, false, 0, 0, 0, 0);
            bytes[] memory steps = new bytes[](1);
            steps[0] = iRouterMultihop.encodeStep(0, 0, 0, address(FXS), FRAXFXSPool, 1, 0, 10_000);
            bytes[] memory routes = new bytes[](1);
            routes[0] = iRouterMultihop.encodeRoute(address(FXS), 10_000, steps, new bytes[](0));
            bytes memory outerRoute = iRouterMultihop.encodeRoute(address(FXS), 10_000, new bytes[](0), routes);
            IFraxswapRouterMultihop.FraxswapParams memory swapParams = IFraxswapRouterMultihop.FraxswapParams(
                address(FRAX),
                1e18,
                address(FXS),
                1e17,
                whale,
                block.timestamp,
                false,
                0,
                bytes32(0),
                bytes32(0),
                outerRoute
            );
            vm.expectEmit(true, true, true, true, bamm);
            emit IBAMM.VaultSwap(whale, int256(amountOut), -1e18);
            vm.expectEmit(true, true, true, true, bamm);
            emit IBAMM.VaultUpdated(whale, int256(amountOut), 0, 0);
            BAMM(bamm).executeActionsAndSwap(action, swapParams);
            vm.stopPrank();
        }
    }

    function test_liquidate_events() public {
        setUpEthereum(18_850_000);
        {
            // mint
            vm.startPrank(Mainnet.AMO_OWNER);
            IERC20(FRAXFXSPool).approve(address(bamm), 100e18);
            BAMM(bamm).mint(address(Mainnet.AMO_OWNER), 100e18);
            vm.stopPrank();
        }

        {
            // Deposit/rent
            vm.startPrank(whale);
            IERC20(FRAX).approve(bamm, 100e18);
            IBAMM.Action memory action = IBAMM.Action(0, 13.865e18, 95e18, whale, 0, 0, false, false, 0, 0, 0, 0);
            BAMM(bamm).executeActions(action);
            vm.stopPrank();
        }

        for (uint256 i = 0; i < 40; ++i) {
            mineBlocksBySecond(5 * 3600);
            BAMM(bamm).addInterest();
            uint256 ltv = ltv(whale);
            console.log("ltv", ltv);
            if (ltv > 0.98e18) {
                hoax(bob);
                vm.expectEmit(true, true, true, false, bamm);
                emit IBAMM.VaultSwap(whale, 0, 0);
                vm.expectEmit(true, true, true, false, bamm);
                emit IBAMM.RentRepaid(whale, 0, 0, 0, false);
                vm.expectEmit(true, true, true, false, bamm);
                emit IBAMM.MicroLiquidate(whale, bob, 0, 0);
                vm.expectEmit(true, true, true, false, bamm);
                emit IBAMM.BAMMState(0, 0, 0, 0);
                BAMM(bamm).microLiquidate(whale);
            }
        }
    }
}
