// SPDX-License-Identifier: ISC
pragma solidity 0.8.23;

import "frax-std/FraxTest.sol";
import "../../BaseTest.t.sol";
import "../../../Constants.sol";

contract BAMMSwapTest is BaseTest {
    IERC20 FRAX = IERC20(0x853d955aCEf822Db058eb8505911ED77F175b99e);
    IERC20 FXS = IERC20(0x3432B6A60D23Ca0dFCa7761B7ab56459D9C964D0);
    address FRAXFXSPool = 0x03B59Bd1c8B9F6C265bA0c3421923B93f15036Fa;

    function setUpEthereum() public {
        vm.createSelectFork(vm.envString("MAINNET_RPC_URL"), 18_850_000);
        iRouterMultihop = IFraxswapRouterMultihop(payable(0x25e9acA5951262241290841b6f863d59D37DC4f0));

        _initializeAccounts();

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
            _feeTo: address(0)
        });

        // create the BAMM and BAMMERC20
        (iVariableInterestRate, variableInterestRate) = deployVariableInterestRate();
        bamm = iBammFactory.createBamm(FRAXFXSPool);
        iBamm = BAMM(bamm);
        iBammErc20 = iBamm.iBammErc20();
        bammErc20 = address(iBammErc20);

        // Set up Alice
        alicePrivateKey = 0xA11CE2;
        alice = payable(vm.addr(alicePrivateKey));
        vm.label(alice, "Alice");

        // Set up Bob
        bobPrivateKey = 0xB0B2;
        bob = payable(vm.addr(bobPrivateKey));
        vm.label(bob, "Bob");
    }

    function test_swap_FRAX_FXS() public {
        setUpEthereum();
        bytes[] memory steps = new bytes[](1);
        steps[0] = iRouterMultihop.encodeStep(0, 0, 0, address(FXS), FRAXFXSPool, 1, 0, 10_000);
        bytes[] memory routes = new bytes[](1);
        routes[0] = iRouterMultihop.encodeRoute(address(FXS), 10_000, steps, new bytes[](0));
        bytes memory outerRoute = iRouterMultihop.encodeRoute(address(FXS), 10_000, new bytes[](0), routes);

        deal(address(FRAX), bob, 100e18);
        vm.startPrank(bob);
        FRAX.approve(Constants.Mainnet.FRAXSWAP_ROUTER_MULTIHOP, 1e18);
        iRouterMultihop.swap(
            IFraxswapRouterMultihop.FraxswapParams(
                address(FRAX),
                1e18,
                address(FXS),
                1e17,
                address(Mainnet.AMO_OWNER),
                block.timestamp,
                false,
                0,
                bytes32(0),
                bytes32(0),
                outerRoute
            )
        );
        vm.stopPrank();
    }

    function test_swap_incorrectOuterRoute_returns0() public {
        setUpEthereum();
        IERC20 DOLA = IERC20(0x865377367054516e17014CcdED1e7d814EDC9ce4);
        address POOL = 0xE57180685E3348589E9521aa53Af0BCD497E884d;

        bytes[] memory steps = new bytes[](1);
        steps[0] = iRouterMultihop.encodeStep(5, 0, 0, address(DOLA), POOL, 1, 0, 10_000);
        bytes[] memory routes = new bytes[](1);
        routes[0] = iRouterMultihop.encodeRoute(address(DOLA), 10_000, steps, new bytes[](0));
        bytes memory outerRoute = iRouterMultihop.encodeRoute(address(DOLA), 10_000, new bytes[](0), routes);

        deal(address(FRAX), bob, 100e18);
        vm.startPrank(bob);
        FRAX.approve(Constants.Mainnet.FRAXSWAP_ROUTER_MULTIHOP, 1e18);

        // Can not do a swap that returns zero because amountOutMinimum can not be set zero
        uint256 amountOut = iRouterMultihop.swap(
            IFraxswapRouterMultihop.FraxswapParams(
                address(FRAX),
                1e18,
                address(FXS),
                0,
                address(Mainnet.AMO_OWNER),
                block.timestamp,
                false,
                0,
                bytes32(0),
                bytes32(0),
                outerRoute
            )
        );
        vm.stopPrank();
        console.log("Amount Out: ", amountOut);
        /// @notice next call to multihop can claim these tokens so technically not lost
        console.log("Balance of Router: ", IERC20(DOLA).balanceOf(address(iRouterMultihop)));
        assertEq({ a: amountOut, b: 0, err: "// THEN: AmountOut return from multihop swap router is maliable" });
    }

    function test_BAMM_swap() public {
        _preSwapState();
        IBAMM.Action memory action = IBAMM.Action(0, 10e18, 10e18, address(bob), 0, 0, false, false, 0, 0, 0, 0);
        BAMM(bamm).executeActions(action);

        logVault("After deposit & rent", bob);

        // Swap
        bytes[] memory steps = new bytes[](1);
        steps[0] = iRouterMultihop.encodeStep(0, 0, 0, address(FXS), FRAXFXSPool, 1, 0, 10_000);
        bytes[] memory routes = new bytes[](1);
        routes[0] = iRouterMultihop.encodeRoute(address(FXS), 10_000, steps, new bytes[](0));
        bytes memory outerRoute = iRouterMultihop.encodeRoute(address(FXS), 10_000, new bytes[](0), routes);
        IFraxswapRouterMultihop.FraxswapParams memory swapParams = IFraxswapRouterMultihop.FraxswapParams(
            address(FRAX),
            1e18,
            address(FXS),
            1,
            bob,
            block.timestamp,
            false,
            0,
            bytes32(0),
            bytes32(0),
            outerRoute
        );
        action = IBAMM.Action(0, 0, 0, address(bob), 0, 0, false, false, 0, 0, 0, 0);
        BAMM(bamm).executeActionsAndSwap(action, swapParams);
        vm.stopPrank();
        logVault("After swap", bob);
    }

    function test_BAMM_swap_incorrect_route_returns0() public {
        _preSwapState();
        IBAMM.Action memory action = IBAMM.Action(0, 10e18, 10e18, address(bob), 0, 0, false, false, 0, 0, 0, 0);
        BAMM(bamm).executeActions(action);

        // Swap
        IERC20 DOLA = IERC20(0x865377367054516e17014CcdED1e7d814EDC9ce4);
        address POOL = 0xE57180685E3348589E9521aa53Af0BCD497E884d;

        bytes[] memory steps = new bytes[](1);
        steps[0] = iRouterMultihop.encodeStep(5, 0, 0, address(DOLA), POOL, 1, 0, 10_000);
        bytes[] memory routes = new bytes[](1);
        routes[0] = iRouterMultihop.encodeRoute(address(DOLA), 10_000, steps, new bytes[](0));
        bytes memory outerRoute = iRouterMultihop.encodeRoute(address(DOLA), 10_000, new bytes[](0), routes);

        logVault("Before Bad swap", bob);

        // Can not do a swap that returns zero because amountOutMinimum can not be set zero
        IFraxswapRouterMultihop.FraxswapParams memory swapParams = IFraxswapRouterMultihop.FraxswapParams(
            address(FRAX),
            /// @notice Locked in BAMM
            1e18,
            address(FXS),
            /// @notice Locked in BAMM
            0,
            bob,
            block.timestamp,
            false,
            0,
            bytes32(0),
            bytes32(0),
            outerRoute
        );

        BAMM.Vault memory vault_before;
        vault_before = iBamm.getUserVault(bob);
        action = IBAMM.Action(0, 0, 0, address(bob), 0, 0, false, false, 0, 0, 0, 0);

        vm.expectRevert(IBAMM.IncorrectAmountOutMinimum.selector);
        BAMM(bamm).executeActionsAndSwap(action, swapParams);
        vm.stopPrank();

        logVault("After Bad swap", bob);

        BAMM.Vault memory vault_after;
        vault_after = iBamm.getUserVault(bob);

        assertEq({ a: vault_before.token0, b: vault_after.token0, err: "// THEN: Incorrect vault value post swap" });
    }

    function test_BAMM_deposit_rent_swap() public {
        _preSwapState();

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
            bob,
            block.timestamp,
            false,
            0,
            bytes32(0),
            bytes32(0),
            outerRoute
        );
        IBAMM.Action memory action = IBAMM.Action(
            0,
            10e18,
            10e18,
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

        logVault("Before rent deposit and swap", bob);
        BAMM(bamm).executeActionsAndSwap(action, swapParams);
        vm.stopPrank();
        logVault("After deposit & rent & swap", bob);
    }

    // ====================================================================
    //                          REVERSIONS
    // ====================================================================

    function test_incorrect_tokenOut_reverts() public {
        _preSwapState();
        IBAMM.Action memory action = IBAMM.Action(0, 10e18, 10e18, address(bob), 0, 0, false, false, 0, 0, 0, 0);
        BAMM(bamm).executeActions(action);

        // Swap
        bytes[] memory steps = new bytes[](1);
        steps[0] = iRouterMultihop.encodeStep(0, 0, 0, address(FXS), address(FRAXFXSPool), 1, 0, 10_000);
        bytes[] memory routes = new bytes[](1);
        routes[0] = iRouterMultihop.encodeRoute(address(FXS), 10_000, steps, new bytes[](0));
        bytes memory outerRoute = iRouterMultihop.encodeRoute(address(FXS), 10_000, new bytes[](0), routes);
        IFraxswapRouterMultihop.FraxswapParams memory swapParams = IFraxswapRouterMultihop.FraxswapParams(
            address(FRAX),
            1e18,
            address(0),
            1,
            bob,
            block.timestamp,
            false,
            0,
            bytes32(0),
            bytes32(0),
            outerRoute
        );
        action = IBAMM.Action(0, 0, 0, address(bob), 0, 0, false, false, 0, 0, 0, 0);

        vm.expectRevert(IBAMM.IncorrectSwapTokens.selector);
        BAMM(bamm).executeActionsAndSwap(action, swapParams);
    }

    function test_incorrect_tokenIn_reverts() public {
        _preSwapState();
        IBAMM.Action memory action = IBAMM.Action(0, 10e18, 10e18, address(bob), 0, 0, false, false, 0, 0, 0, 0);
        BAMM(bamm).executeActions(action);

        // Swap
        bytes[] memory steps = new bytes[](1);
        steps[0] = iRouterMultihop.encodeStep(0, 0, 0, address(FXS), address(FRAXFXSPool), 1, 0, 10_000);
        bytes[] memory routes = new bytes[](1);
        routes[0] = iRouterMultihop.encodeRoute(address(FXS), 10_000, steps, new bytes[](0));
        bytes memory outerRoute = iRouterMultihop.encodeRoute(address(FXS), 10_000, new bytes[](0), routes);
        IFraxswapRouterMultihop.FraxswapParams memory swapParams = IFraxswapRouterMultihop.FraxswapParams(
            address(0),
            1e18,
            address(FXS),
            1,
            bob,
            block.timestamp,
            false,
            0,
            bytes32(0),
            bytes32(0),
            outerRoute
        );
        action = IBAMM.Action(0, 0, 0, address(bob), 0, 0, false, false, 0, 0, 0, 0);

        vm.expectRevert(IBAMM.IncorrectSwapTokens.selector);
        BAMM(bamm).executeActionsAndSwap(action, swapParams);
    }

    function test_swap_cannot_make_user_insolvent() public {
        _preSwapState();
        IBAMM.Action memory action = IBAMM.Action(0, 10e18, 10e18, address(bob), 0, 0, false, false, 0, 0, 0, 0);
        BAMM(bamm).executeActions(action);

        // Swap
        IERC20 DOLA = IERC20(0x865377367054516e17014CcdED1e7d814EDC9ce4);
        address POOL = 0xE57180685E3348589E9521aa53Af0BCD497E884d;

        /// @notice Swap will effecitvely remove tokens from vault st they are claimable via next blockspace
        bytes[] memory steps = new bytes[](1);
        steps[0] = iRouterMultihop.encodeStep(5, 0, 0, address(DOLA), POOL, 1, 0, 10_000);
        bytes[] memory routes = new bytes[](1);
        routes[0] = iRouterMultihop.encodeRoute(address(DOLA), 10_000, steps, new bytes[](0));
        bytes memory outerRoute = iRouterMultihop.encodeRoute(address(DOLA), 10_000, new bytes[](0), routes);

        // Can not do a swap that returns zero because amountOutMinimum can not be set zero
        /*IFraxswapRouterMultihop.FraxswapParams memory swapParams = IFraxswapRouterMultihop.FraxswapParams(
            address(FRAX),
            /// @notice Locked in BAMM
            25e18,
            address(FXS),
            /// @notice Locked in BAMM
            0,
            bob,
            block.timestamp,
            false,
            0,
            bytes32(0),
            bytes32(0),
            outerRoute
        );

        BAMM.Vault memory vault_before;
        vault_before = iBamm.getUserVault(bob);
        action = IBAMM.Action(0, 0, 0, address(bob), 0, 0, false, false, 0, 0, 0, 0);

        vm.expectRevert(IBAMM.NotSolvent.selector);
        BAMM(bamm).executeActionsAndSwap(action, swapParams);*/
    }

    // ====================================================================
    //                          HELPERS
    // ====================================================================

    function _preSwapState() internal {
        setUpEthereum();

        // Lend Lp tokens
        vm.startPrank(Mainnet.AMO_OWNER);
        IERC20(FRAXFXSPool).approve(address(bamm), 100e18);
        BAMM(bamm).mint(address(Mainnet.AMO_OWNER), 100e18);
        vm.stopPrank();

        // Deposit/rent
        deal(address(FRAX), bob, 100e18);
        vm.startPrank(bob);
        IERC20(FRAX).approve(bamm, 100e18);
    }

    function logVault(string memory label, address adr) public view {
        (int256 token0Amount, int256 token1Amount, int256 rented) = BAMM(bamm).userVaults(adr);
        console.log(label, uint256(token0Amount), uint256(token1Amount), uint256(rented));
    }
}
