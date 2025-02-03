// SPDX-License-Identifier: ISC
pragma solidity ^0.8.19;

import "frax-std/FraxTest.sol";
import "../../BaseTest.t.sol";
import "../../helpers/BAMMTestHelper.sol";
import { BAMMUIHelper } from "../../../contracts/BAMMUIHelper.sol";
import "../../../Constants.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";

contract BAMMUIHelperTest is BaseTest, BAMMTestHelper {
    function setUp() public virtual {
        defaultSetup();
    }

    function test_calcZap() public {
        uint256 liquidity = mint(alice, 1000e18, 1000e18);
        int256 ratio = 0.1e18;
        int256 targetLTV = 0.9428091e18;
        for (uint256 i = 1; i < 50; i++) {
            int256 vault0 = 1e18;
            int256 vault1 = 0;
            (int256 toRent, int256 swap) = iBammUIHelper.calcZap(iBamm, vault0, vault1, 0, targetLTV, ratio);
            ratio = (ratio * 110) / 100;
        }
    }

    function test_executeZap1() public {
        uint256 ratio = bound(uint256(1_128_404_648_220_539_226), 0.001e18, 1000e18);
        executeZap(ratio, 0.9428091e18);
    }

    function testFuzz_executeZap(uint256 ratio, uint256 targetLTV) public {
        ratio = bound(ratio, 0.001e18, 1000e18);
        targetLTV = bound(targetLTV, 0.001e18, 0.9749e18);
        executeZap(ratio, targetLTV);
    }

    function executeZap(uint256 ratio, uint256 targetLTV) public {
        uint256 liquidity = mint(alice, 1000e18, 1000e18);
        int256 vault0 = 1e18;
        int256 vault1 = 0;
        (int256 toRent, int256 swap) = iBammUIHelper.calcZap(
            iBamm,
            vault0,
            vault1,
            0,
            int256(targetLTV),
            int256(ratio)
        );
        console.log("toRent/swap");
        console.logInt(toRent);
        console.logInt(swap);
        // Bob add tokens to the vault
        deal(token0, bob, uint256(vault0));
        deal(token1, bob, uint256(vault1));
        vm.prank(bob);
        IERC20(token0).approve(bamm, uint256(vault0));
        vm.prank(bob);
        IERC20(token1).approve(bamm, uint256(vault1));
        IBAMM.Action memory action = IBAMM.Action(vault0, vault1, toRent, bob, 0, 0, false, false, 0, 0, 0, 0);
        // Swap
        IFraxswapRouterMultihop.FraxswapParams memory swapParams = getFraxswapParams(swap);
        vm.prank(bob);
        BAMM(bamm).executeActionsAndSwap(action, swapParams);
        BAMMUIHelper.BAMMState memory state = iBammUIHelper.getBAMMState(iBamm);
        BAMMUIHelper.BAMMVault memory vault = iBammUIHelper.getVaultState(iBamm, bob);
        uint256 vaultRatio = uint256(
            (((vault.token1 * int256(state.reserve0)) / int256(state.reserve1)) * 1e18) / vault.token0
        );
        console.log(vault.ltv, vaultRatio);

        assertApproxEqRel(uint256(vaultRatio), uint256(ratio), 1e13);
        assertApproxEqRel(uint256(vault.ltv), uint256(targetLTV), 1e13);
    }

    function testFuzz_exitZap(uint256 ratio, uint256 targetLTV) public {
        ratio = bound(ratio, 0.001e18, 1000e18);
        targetLTV = bound(targetLTV, 0.001e18, 0.9749e18);
        executeZap(ratio, targetLTV);
        BAMMUIHelper.BAMMVault memory vault = iBammUIHelper.getVaultState(iBamm, bob);
        console.log("token0/token1/rented");
        console.logInt(vault.token0);
        console.logInt(vault.token1);
        console.logInt(vault.rented);
        (int256 toRent, int256 swap) = iBammUIHelper.calcZap(iBamm, vault.token0, vault.token1, vault.rented, 0, 1e10);
        console.log("toRent/swap");
        console.logInt(toRent);
        console.logInt(swap);
        IBAMM.Action memory action = IBAMM.Action(0, 0, toRent, bob, 0, 0, false, false, 0, 0, 0, 0);
        // Swap
        IFraxswapRouterMultihop.FraxswapParams memory swapParams = getFraxswapParams(swap);
        vm.prank(bob);
        BAMM(bamm).executeActionsAndSwap(action, swapParams);

        vault = iBammUIHelper.getVaultState(iBamm, bob);
        console.log("token0/token1/rented");
        console.logInt(vault.token0);
        console.logInt(vault.token1);
        console.logInt(vault.rented);
    }

    function test_calcRentForLTV() public {
        int256 debt = 0;
        for (uint256 i = 0; i < 100; ++i) {
            debt += 0.01e18;
            int256 toRent = iBammUIHelper.calcRentForLTV(1e18, -debt, 0.975e18);
            //console.logInt(debt);
            //console.logInt(toRent);
        }
    }

    function testFuzz_maxborrow_calcRentForLTV_(uint256 _token0) public {
        uint256 liquidity = mint(alice, 10_000e18, 10_000e18);
        BAMMUIHelper.BAMMState memory state = iBammUIHelper.getBAMMState(iBamm);
        _token0 = bound(_token0, 0.001e18, 1000e18);
        uint256 _token1 = (0.6358e18 * _token0 * state.reserve1) / (state.reserve0 * 1e18);
        uint256 _targetLTV = 0.9749e18;
        console.log(_token0, _token1, _targetLTV);
        int256 toRent = iBammUIHelper.calcRentForLTV(
            iBamm,
            int256(_token0),
            -int256(_token1),
            int256(0),
            int256(_targetLTV)
        );
        require(toRent > 0, "Can not rent");
        calcRentForLTV2(int256(_token0), -int256(_token1), int256(_targetLTV));
    }

    function testFuzz_calcRentForLTV(uint256 _token0, uint256 _token1, uint256 _targetLTV) public {
        uint256 liquidity = mint(alice, 10_000e18, 10_000e18);
        BAMMUIHelper.BAMMState memory state = iBammUIHelper.getBAMMState(iBamm);
        _token0 = bound(_token0, 0.001e18, 1000e18);
        _token1 = (bound(_token1, 0.001e18, 1e18) * _token0 * state.reserve1) / (state.reserve0 * 1e18);
        _targetLTV = bound(_targetLTV, 0.001e18, 0.9749e18);
        calcRentForLTV2(int256(_token0), -int256(_token1), int256(_targetLTV));
    }

    function calcRentForLTV2(int256 _token0, int256 _token1, int256 _targetLTV) public {
        int256 toRent = iBammUIHelper.calcRentForLTV(iBamm, _token0, _token1, int256(0), _targetLTV);
        if (toRent > 0) {
            // Bob add tokens to the vault
            if (_token0 > 0) deal(token0, bob, uint256(_token0));
            if (_token1 > 0) deal(token1, bob, uint256(_token1));

            if (_token0 > 0) {
                vm.prank(bob);
                IERC20(token0).approve(bamm, uint256(_token0));
            }
            if (_token1 > 0) {
                vm.prank(bob);
                IERC20(token1).approve(bamm, uint256(_token1));
            }
            IBAMM.Action memory action = IBAMM.Action(_token0, _token1, toRent, bob, 0, 0, false, false, 0, 0, 0, 0);
            vm.prank(bob);
            BAMM(bamm).executeActions(action);
        }
    }

    function test_getChartData0() public {
        uint256 liquidity = mint(alice, 10_000e18, 10_000e18);
        BAMMUIHelper.BAMMState memory state = iBammUIHelper.getBAMMState(iBamm);
        calcRentForLTV2(-0.5e18, int256((1e18 * state.reserve1) / state.reserve0), 0.9749e18);
        BAMMUIHelper.BAMMVault memory vault = iBammUIHelper.getVaultState(iBamm, bob);
        BAMMUIHelper.ChartPoint[1000] memory points = iBammUIHelper.getChartData0(iBamm, bob);
        console.log("price value");
        for (uint256 i = 0; i < 1000; ++i) {
            console.logString(
                string.concat(
                    Strings.toStringSigned(points[i].price),
                    " ",
                    Strings.toStringSigned(points[i].value),
                    " ",
                    Strings.toStringSigned(points[i].blValue)
                )
            );
        }
    }

    function test_getChartData1() public {
        uint256 liquidity = mint(alice, 10_000e18, 10_000e18);
        BAMMUIHelper.BAMMState memory state = iBammUIHelper.getBAMMState(iBamm);
        calcRentForLTV2(-0.5e18, int256((1e18 * state.reserve1) / state.reserve0), 0.9749e18);
        BAMMUIHelper.BAMMVault memory vault = iBammUIHelper.getVaultState(iBamm, bob);
        BAMMUIHelper.ChartPoint[1000] memory points = iBammUIHelper.getChartData1(iBamm, bob);
        console.log("price value");
        for (uint256 i = 0; i < 1000; ++i) {
            console.logString(
                string.concat(
                    Strings.toStringSigned(points[i].price),
                    " ",
                    Strings.toStringSigned(points[i].value),
                    " ",
                    Strings.toStringSigned(points[i].blValue)
                )
            );
        }
    }

    function getFraxswapParams(
        int256 swap
    ) internal returns (IFraxswapRouterMultihop.FraxswapParams memory swapParams) {
        if (swap < 0) {
            // Swap token0  for token1
            uint256 minAmountOut = (iBamm.pair().getAmountOut(uint256(-swap), token0) * 99_999) / 100_000; // minor slippage
            bytes[] memory steps = new bytes[](1);
            steps[0] = iRouterMultihop.encodeStep(0, 0, 0, token1, address(iBamm.pair()), 1, 0, 10_000);
            bytes[] memory routes = new bytes[](1);
            routes[0] = iRouterMultihop.encodeRoute(token1, 10_000, steps, new bytes[](0));
            bytes memory outerRoute = iRouterMultihop.encodeRoute(token1, 10_000, new bytes[](0), routes);
            swapParams = IFraxswapRouterMultihop.FraxswapParams(
                token0,
                uint256(-swap),
                token1,
                minAmountOut,
                bob,
                block.timestamp,
                false,
                0,
                bytes32(0),
                bytes32(0),
                outerRoute
            );
        } else if (swap > 0) {
            // Swap token1  for token0
            uint256 minAmountOut = (uint256(swap) * 99_999) / 100_000; // minor slippage
            uint256 swapIn = iBamm.pair().getAmountIn(uint256(swap), token0);
            bytes[] memory steps = new bytes[](1);
            steps[0] = iRouterMultihop.encodeStep(0, 0, 0, token0, address(iBamm.pair()), 1, 0, 10_000);
            bytes[] memory routes = new bytes[](1);
            routes[0] = iRouterMultihop.encodeRoute(token0, 10_000, steps, new bytes[](0));
            bytes memory outerRoute = iRouterMultihop.encodeRoute(token0, 10_000, new bytes[](0), routes);
            swapParams = IFraxswapRouterMultihop.FraxswapParams(
                token1,
                uint256(swapIn),
                token0,
                minAmountOut,
                bob,
                block.timestamp,
                false,
                0,
                bytes32(0),
                bytes32(0),
                outerRoute
            );
        }
    }

    function mint(address user, uint256 _amount0Desired, uint256 _amount1Desired) public returns (uint256 liquidity) {
        deal(token0, user, _amount0Desired);
        deal(token1, user, _amount1Desired);
        vm.prank(user);
        IERC20(token0).approve(router, _amount0Desired);
        vm.prank(user);
        IERC20(token1).approve(router, _amount1Desired);
        uint256 amount0;
        uint256 amount1;
        vm.prank(user);
        (amount0, amount1, liquidity) = iRouter.addLiquidity({
            tokenA: token0,
            tokenB: token1,
            amountADesired: _amount0Desired,
            amountBDesired: _amount1Desired,
            amountAMin: 0,
            amountBMin: 0,
            to: user,
            deadline: block.timestamp + 1
        });
        iBammErc20.approve(bamm, liquidity);
        _bamm_mint(bamm, user, user, pair, liquidity);
    }
}
