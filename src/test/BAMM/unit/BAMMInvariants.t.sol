// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import "../../BaseTest.t.sol";
import "../../helpers/BAMMTestHelper.sol";

contract BAMMInvariants is BaseTest, BAMMTestHelper {
    uint256 constant DAY = 86_400;
    uint256 constant HOUR = 3600;

    function setUp() public {
        defaultSetup();
    }

    function test_BAMM_Invariants() public {
        uint256 liquidity = mint(alice, 1e18, 1e18);
        skip(HOUR);
        depositToken0(bob, 1e18);
        skip(HOUR);
        rent(bob, int256((liquidity * 4) / 10));
        skip(HOUR);
        depositToken1(claire, 1e18);
        skip(HOUR);
        rent(claire, int256((liquidity * 5) / 10));
        skip(HOUR);
        depositToken0(bob, 1e18);
        logUserVault(alice);
        logUserVault(bob);
        logUserVault(claire);
        skip(HOUR);
        marketBuy(10_000e18);
        closePosition(bob);
        marketSell(1000e18);
        closePosition(claire);
        redeem(alice, iBammErc20.balanceOf(alice));
        console.log(IERC20(token0).balanceOf(bamm), IERC20(token0).balanceOf(bamm), iPair.balanceOf(bamm));
        logUserVault(alice);
        logUserVault(bob);
        logUserVault(claire);
    }

    function closePosition(address user) public {
        IBAMM.Action memory action;
        action.closePosition = true;
        vm.prank(user);
        iBamm.executeActions(action);
        checkInvariants();
    }

    function rent(address user, int256 amount) public {
        _bamm_rent(bamm, user, amount);
        checkInvariants();
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
        checkInvariants();
    }

    function redeem(address user, uint256 _amount) public {
        vm.prank(user);
        iBamm.redeem(user, _amount);
        checkInvariants();
    }

    function depositToken0(address user, int256 amount) public {
        checkInvariants();
        _bamm_deposit({
            _bamm: bamm,
            _token0: token0,
            _token1: token1,
            _user: user,
            _token0Amount: amount,
            _token1Amount: 0
        });
        checkInvariants();
    }

    function depositToken1(address user, int256 amount) public {
        checkInvariants();
        _bamm_deposit({
            _bamm: bamm,
            _token0: token0,
            _token1: token1,
            _user: user,
            _token0Amount: 0,
            _token1Amount: amount
        });
        checkInvariants();
    }

    function checkInvariants() public {
        checkVaults();
    }

    function checkVaults() public {
        int256 sumToken0;
        int256 sumToken1;
        int256 sumRented;
        BAMM.Vault memory vault = getUserVault(alice);
        sumToken0 += vault.token0;
        sumToken1 += vault.token1;
        sumRented += vault.rented;
        vault = getUserVault(bob);
        sumToken0 += vault.token0;
        sumToken1 += vault.token1;
        sumRented += vault.rented;
        vault = getUserVault(claire);
        sumToken0 += vault.token0;
        sumToken1 += vault.token1;
        sumRented += vault.rented;
        vault = getUserVault(dave);
        sumToken0 += vault.token0;
        sumToken1 += vault.token1;
        sumRented += vault.rented;
        vault = getUserVault(eric);
        sumToken0 += vault.token0;
        sumToken1 += vault.token1;
        sumRented += vault.rented;
        vault = getUserVault(frank);
        sumToken0 += vault.token0;
        sumToken1 += vault.token1;
        sumRented += vault.rented;
        assertEq(uint256(sumRented), uint256(iBamm.sqrtRented()));
        assertEq(uint256(sumToken0), IERC20(token0).balanceOf(bamm));
        assertEq(uint256(sumToken1), IERC20(token1).balanceOf(bamm));
        assert(solvent(alice));
        assert(solvent(bob));
        assert(solvent(claire));
        assert(solvent(dave));
        assert(solvent(eric));
        assert(solvent(frank));
    }

    function getUserVault(address user) public view returns (BAMM.Vault memory vault) {
        (vault.token0, vault.token1, vault.rented) = iBamm.userVaults(user);
    }

    function logUserVault(address user) public {
        BAMM.Vault memory vault;
        (vault.token0, vault.token1, vault.rented) = iBamm.userVaults(user);
        console.log(vm.getLabel(user));
        console.log("%d,%d,%d", uint256(vault.token0), uint256(vault.token1), uint256(vault.rented));
    }
}
