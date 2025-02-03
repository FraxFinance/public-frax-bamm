// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import "../BaseTest.t.sol";

contract BAMMTestHelper is BaseTest {
    error CannotDepositNegative();

    address freshUser = address(0xFEDBAD);
    address badActor = address(0xbadBEEF);

    function _bamm_deposit(
        address _bamm,
        address _token0,
        address _token1,
        address _user,
        int256 _token0Amount,
        int256 _token1Amount
    ) internal {
        if (_token0Amount < 0 || _token1Amount < 0) revert CannotDepositNegative();

        // deal and approve token0/token1 spending
        if (_token0Amount > 0) {
            deal(_token0, _user, uint256(_token0Amount));
            vm.prank(_user);
            IERC20(_token0).approve(bamm, uint256(_token0Amount));
        }
        if (_token1Amount > 0) {
            deal(_token1, _user, uint256(_token1Amount));
            vm.prank(_user);
            IERC20(_token1).approve(bamm, uint256(_token1Amount));
        }

        // setup action
        IBAMM.Action memory action;
        action.token0Amount = _token0Amount;
        action.token1Amount = _token1Amount;

        // execute deposit
        vm.prank(_user);
        BAMM(_bamm).executeActions(action);
    }

    error CannotWithdrawPositive();

    function _bamm_withdraw(address _bamm, address _user, int256 _token0Amount, int256 _token1Amount) internal {
        if (_token0Amount > 0 || _token1Amount > 0) revert CannotWithdrawPositive();

        // setup action
        IBAMM.Action memory action;
        action.token0Amount = _token0Amount;
        action.token1Amount = _token1Amount;

        // execute withdraw
        vm.prank(_user);
        BAMM(_bamm).executeActions(action);
    }

    function _bamm_mint(address _bamm, address _user, address _to, address _pair, uint256 _amountPair) internal {
        vm.startPrank(_user);
        IERC20(_pair).approve(_bamm, _amountPair);
        BAMM(_bamm).mint(_to, _amountPair);
        vm.stopPrank();
    }

    function _bamm_rent(address _bamm, address _user, int256 _rent) internal {
        IBAMM.Action memory action;
        action.rent = _rent;
        vm.prank(_user);
        BAMM(_bamm).executeActions(action);
    }

    function _bamm_swap(
        address _bamm,
        address _user,
        address _tokenIn,
        uint256 _amountIn,
        address _recipient
    ) internal {
        address tokenOut = _tokenIn != address(BAMM(_bamm).token0())
            ? address(BAMM(_bamm).token0())
            : address(BAMM(_bamm).token1());

        // setup action
        IBAMM.Action memory action;
        IFraxswapRouterMultihop.FraxswapParams memory swapParams = _createSwapParams({
            _tokenIn: _tokenIn,
            _amountIn: _amountIn,
            _tokenOut: tokenOut,
            _recipient: _recipient
        });

        // execute swap
        vm.prank(_user);
        BAMM(_bamm).executeActionsAndSwap(action, swapParams);
    }

    function _createSwapParams(
        address _tokenIn,
        uint256 _amountIn,
        address _tokenOut,
        address _recipient
    ) internal view returns (IFraxswapRouterMultihop.FraxswapParams memory swapParams) {
        // create single step
        IFraxswapRouterMultihop.FraxswapStepData memory step;
        step.pool = IFraxswapFactory(iBammFactory.iFraxswapFactory()).getPair(_tokenIn, _tokenOut);
        step.extraParam1 = 1; // For fraxswap v2
        step.percentOfHop = 10_000;
        step.tokenOut = _tokenOut;

        bytes[] memory routes = new bytes[](1);

        // create single route
        IFraxswapRouterMultihop.FraxswapRoute memory route;
        route.tokenOut = _tokenOut;
        route.percentOfHop = 10_000;
        route.steps = new bytes[](1);
        route.nextHops = new bytes[](0);
        route.steps[0] = abi.encode(step);

        // Encode the single route
        routes[0] = abi.encode(route);
        route.steps = new bytes[](0);
        route.nextHops = routes;

        // create swap params
        swapParams.tokenIn = _tokenIn;
        swapParams.amountIn = _amountIn;
        swapParams.tokenOut = _tokenOut;
        swapParams.recipient = _recipient;
        swapParams.deadline = block.timestamp;
        swapParams.route = abi.encode(route);
        swapParams.amountOutMinimum = 1;
    }

    function marketBuy(uint256 amount) public {
        iPair.sync();
        uint256 amountOut = iPair.getAmountOut(amount, token0);
        deal(token0, address(this), amount);
        IERC20(token0).transfer(pair, amount);
        iPair.swap(0, amountOut, address(this), "");
    }

    function marketSell(uint256 amount) public {
        iPair.sync();
        uint256 amountOut = iPair.getAmountOut(amount, token1);
        deal(token1, address(this), amount);
        IERC20(token1).transfer(pair, amount);
        iPair.swap(amountOut, 0, address(this), "");
    }

    function _dealAndApproveBamm(address user, uint256 token0amt, uint256 token1amt) public {
        if (token0amt > 0) deal(address(iToken0), user, token0amt);
        if (token1amt > 0) deal(address(iToken1), user, token1amt);

        vm.startPrank(user);
        iToken0.approve(bamm, token0amt);
        iToken1.approve(bamm, token1amt);
        vm.stopPrank();
    }
}
