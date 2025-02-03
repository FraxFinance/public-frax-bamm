// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import "../../helpers/BAMMTestHelper.sol";
import { IFraxswapFactory } from "src/contracts/factories/BAMMFactory.sol";

struct FraxswapRoute {
    address tokenOut;
    uint256 amountOut;
    uint256 percentOfHop;
    bytes[] steps;
    bytes[] nextHops;
}

struct FraxswapStepData {
    uint8 swapType;
    uint8 directFundNextPool;
    uint8 directFundThisPool;
    address tokenOut;
    address pool;
    uint256 extraParam1;
    uint256 extraParam2;
    uint256 percentOfHop;
}

contract SwapTest is BAMMTestHelper {
    function setUp() public virtual {
        defaultSetup();

        /// GIVEN: tester has minted bamm
        uint256 amount = iPair.balanceOf(tester);
        vm.startPrank(tester);
        iPair.approve(bamm, amount);
        iBamm.mint(tester, amount);
        vm.stopPrank();

        /// GIVEN: tester1 depesits token0, token1 as collateral
        _bamm_deposit({
            _bamm: bamm,
            _token0: token0,
            _token1: token1,
            _user: tester,
            _token0Amount: 1e18,
            _token1Amount: 1e18
        });

        /// GIVEN: tester2 deposits token0 as collateral
        _bamm_deposit({
            _bamm: bamm,
            _token0: token0,
            _token1: token1,
            _user: tester2,
            _token0Amount: 1e19,
            _token1Amount: 0
        });

        // GIVEN: tester2 has rented an amount
        _bamm_rent({ _bamm: bamm, _user: tester2, _rent: int256(1e18) });
    }

    function test_Swap_NotSolventLTV_reverts() public {
        (int256 token0Vault, , ) = iBamm.userVaults(tester2);

        IBAMM.Action memory action;
        IFraxswapRouterMultihop.FraxswapParams memory swapParams = _createSwapParams({
            _tokenIn: token0,
            _amountIn: uint256(token0Vault - 1),
            _tokenOut: token1,
            _recipient: tester2
        });

        vm.prank(tester2);
        vm.expectRevert(IBAMM.NotSolvent.selector);
        iBamm.executeActionsAndSwap({ action: action, swapParams: swapParams });
    }

    function test_Swap_NotSolventToken_reverts() public {
        (int256 token0Vault, , ) = iBamm.userVaults(tester2);
        IBAMM.Action memory action;
        IFraxswapRouterMultihop.FraxswapParams memory swapParams = _createSwapParams({
            _tokenIn: token0,
            _amountIn: uint256(token0Vault + 1),
            _tokenOut: token1,
            _recipient: tester2
        });

        vm.prank(tester2);
        vm.expectRevert(IBAMM.NotSolvent.selector);
        iBamm.executeActionsAndSwap({ action: action, swapParams: swapParams });
    }

    function test_Swap_DivideByZero_reverts() public {
        (int256 token0Vault, , ) = iBamm.userVaults(tester2);
        IBAMM.Action memory action;
        IFraxswapRouterMultihop.FraxswapParams memory swapParams = _createSwapParams({
            _tokenIn: token0,
            _amountIn: uint256(token0Vault),
            _tokenOut: token1,
            _recipient: tester2
        });

        vm.prank(tester2);
        vm.expectRevert(); // dev: solidity 0x12 error
        iBamm.executeActionsAndSwap({ action: action, swapParams: swapParams });
    }

    function test_Swap_succeeds() public {}

    function test_swapTooMuch_reverts() public {
        _dealAndApproveBamm(alice, 0, 50e18);
        _dealAndApproveBamm(bob, 0, 50e18);

        IBAMM.Action memory action;
        action.token1Amount = 50e18;

        vm.prank(alice);
        iBamm.executeActions(action);

        vm.prank(bob);
        iBamm.executeActions(action);

        uint256 expToken0 = iPair.getAmountOut(50e18, address(iToken1));

        action.token0Amount -= int256(expToken0);
        action.token1Amount = 0;

        IFraxswapRouterMultihop.FraxswapParams memory swapParams;
        swapParams = _createSwapParams(address(iToken1), 100e18, address(iToken0), bamm);

        vm.expectRevert(IBAMM.NotSolvent.selector);
        vm.prank(alice);
        iBamm.executeActionsAndSwap(action, swapParams);
    }

    function test_swapTooMuch_overFlow_solvencyCheck_reverts() public {
        _dealAndApproveBamm(alice, 0, 50e18);
        _dealAndApproveBamm(bob, 0, 500e18);

        IBAMM.Action memory action;
        action.token1Amount = 50e18;

        vm.prank(alice);
        iBamm.executeActions(action);

        vm.prank(bob);
        iBamm.executeActions(action);

        uint256 expToken0 = iPair.getAmountOut(50e18, address(iToken1));

        action.token0Amount -= int256(expToken0);
        action.token1Amount = 0;
        action.rent = 20e18;

        IFraxswapRouterMultihop.FraxswapParams memory swapParams;
        swapParams = _createSwapParams(address(iToken1), 100e18, address(iToken0), bamm);

        vm.expectRevert(IBAMM.NotSolvent.selector);
        vm.prank(alice);
        iBamm.executeActionsAndSwap(action, swapParams);
    }

    function test_swapInvalidToken_reverts() public {
        _dealAndApproveBamm(alice, 0, 100e18);

        IBAMM.Action memory action;
        action.token1Amount = 100e18;

        vm.prank(alice);
        iBamm.executeActions(action);

        uint256 expToken0 = iPair.getAmountOut(100e18, address(iToken1));

        action.token0Amount -= int256(expToken0);
        action.token1Amount = 0;
        address otherToken = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
        IFraxswapRouterMultihop.FraxswapParams memory swapParams;
        swapParams = _createSwapParams(address(iToken1), 100e18, address(otherToken), bamm);

        vm.expectRevert(IBAMM.IncorrectSwapTokens.selector);
        vm.prank(alice);
        iBamm.executeActionsAndSwap(action, swapParams);

        swapParams = _createSwapParams(address(otherToken), 100e18, address(iToken0), bamm);
        vm.expectRevert(IBAMM.IncorrectSwapTokens.selector);
        vm.prank(alice);
        iBamm.executeActionsAndSwap(action, swapParams);
    }

    function test_swapOverridesRecipient_succeeds() public {
        _dealAndApproveBamm(alice, 0, 100e18);

        IBAMM.Action memory action;
        action.token1Amount = 100e18;
        uint256 swapAmount = 1e18;

        vm.prank(alice);
        iBamm.executeActions(action);

        uint256 expToken0 = iPair.getAmountOut(swapAmount, address(iToken1));

        action.token1Amount = 0;
        IFraxswapRouterMultihop.FraxswapParams memory swapParams;
        swapParams = _createSwapParams(token1, swapAmount, token0, alice);

        uint256 aliceBalanceBefore = iToken0.balanceOf(alice);
        uint256 bammBalanceBefore = iToken0.balanceOf(bamm);

        vm.prank(alice);
        iBamm.executeActionsAndSwap(action, swapParams);

        assertEq({
            a: iToken0.balanceOf(alice),
            b: aliceBalanceBefore,
            err: "Alice should not be able to receive swapped tokens"
        });
        assertEq({
            a: iToken0.balanceOf(bamm) - bammBalanceBefore,
            b: expToken0,
            err: "BAMM did not receive the swapped tokens"
        });
    }
}
