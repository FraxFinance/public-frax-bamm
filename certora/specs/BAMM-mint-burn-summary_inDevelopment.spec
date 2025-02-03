import "MathSummaries.spec";
import "../specs_fromSetup/unresolved_BAMM.spec";
import "Fraxswap_cvl.spec";

using BAMMERC20 as BammERC20;

methods
{
	function PRECISION() external returns (uint256) envfree;
	// harness methods declared envfree
	function get_sqrtRented() external returns (int256) envfree;
	function get_rentedMultiplier() external returns (uint256) envfree;
	function getSqrtBalance() external returns (uint256) envfree;
	function getSqrtReserve() external returns (uint256) envfree;
	function getSqrtRentedReal() external returns (uint256) envfree;

	function lpBalance(address) external returns (uint256) envfree;
	function BAMMBalance(address) external returns (uint256) envfree;
	function token0Balance(address) external returns (uint256) envfree;
	function token1Balance(address) external returns (uint256) envfree;

    function lpTotalSupply() external returns (uint256) envfree;
	function BAMMTotalSupply() external returns (uint256) envfree;
	function token0TotalSupply() external returns (uint256) envfree;
	function token1TotalSupply() external returns (uint256) envfree;

	function get_token0() external returns (address) envfree;
	function get_token1() external returns (address) envfree;
	function get_BAMMToken() external returns (address) envfree;
	function get_lpToken() external returns (address) envfree;

	function get_timeSinceLastInterestPayment() external returns (uint256) envfree;
}

// borrow - repay inverse LP balance
// STATUS: TIMEOUT
rule borrowRepayInverseLpBalance(){
	env e;
	address user;
	safeAssumptions(e, user);

	IBAMM.Action borrow_action;

	require get_timeSinceLastInterestPayment() == e.block.timestamp;
	
	// borrowing
	require borrow_action.rent > 0;
	require !borrow_action.closePosition;
	require borrow_action.token0Amount == 0;
	require borrow_action.token1Amount == 0;
	
	uint256 BAMM_pair_bal_before = pair.balanceOf(currentContract);

	IFraxswapRouterMultihop.FraxswapParams swapParams_borrow;

	// requiring that the fraxswap pair's LP balance if 0 so that the LP balance of pair when burning is what was sent by the BAMM during borrow
	require pair.balanceOf(pair) == 0;
	
	executeActionsAndSwap(e, borrow_action, swapParams_borrow);
	
	IBAMM.Action repay_action;
	// repaying borrowed amount
	require repay_action.rent == -borrow_action.rent;
	require !repay_action.closePosition;
	require repay_action.token0Amount == 0;
	require repay_action.token1Amount == 0;

	IFraxswapRouterMultihop.FraxswapParams swapParams_repay;
	executeActionsAndSwap(e, repay_action, swapParams_repay);

	uint256 BAMM_pair_bal_after = pair.balanceOf(currentContract);
	
	assert BAMM_pair_bal_after >= BAMM_pair_bal_before,"rented amount before and after should be the same";
}


//////////////////////////////////////// Utility functions //////////////////////////////////////// 

// A manual method dispatcher that allows to put constrains on some of the arguments.
// Works for all public non-view methods
function callMethodWithArgs(env e, method f, address to, uint256 amount)
{
	if (f.selector == sig:redeem(address,uint256).selector)	{ redeem(e, to, amount); }
	if (f.selector == sig:mint(address,uint256).selector) {	mint(e, to, amount); }
	if (f.selector == sig:microLiquidate(address).selector) { microLiquidate(e, to); }
	if (f.selector == sig:addInterest().selector) { addInterest(e);	}
	if (f.selector == sig:executeActions(IBAMM.Action).selector) {
		IBAMM.Action action;
		require action.to == to;
		require action.rent == amount || action.rent == -amount;
		executeActions(e, action);
	}
	if (f.selector == sig:executeActionsAndSwap(IBAMM.Action,IFraxswapRouterMultihop.FraxswapParams).selector) {
		IBAMM.Action action;
		require action.to == to;
		require action.rent == amount || action.rent == -amount;
		IFraxswapRouterMultihop.FraxswapParams swapParams;
		executeActionsAndSwap(e, action, swapParams);
	}
	else {
		// it will only go here for view methods
		calldataarg args;
		f(e, args);
	}
}

// ensures that total balance of given addresses is no more than total supply for each ERC20 in the scene
// Correctly handles situations when some of the three addresses are actually identical
function balanceLessThanTotalSupply(address a, address b, address c) returns bool {
	if (a != b && a != c && b != c) {
		return 
			   token0Balance(a) + token0Balance(b) + token0Balance(c) <= token0TotalSupply()
			&& token1Balance(a) + token1Balance(b) + token1Balance(c) <= token1TotalSupply()
			&& lpBalance(a) + lpBalance(b) + lpBalance(c) <= lpTotalSupply()
			&& pairERC20.balanceOf(a) + pairERC20.balanceOf(b) + pairERC20.balanceOf(c) + pairERC20.balanceOf(pair) <= pairERC20.totalSupply()
			&& BAMMBalance(a) + BAMMBalance(b) + BAMMBalance(c)<= BAMMTotalSupply();
	}
	
	if (a == b && a != c) {
		return 
			   token0Balance(a) + token0Balance(c) <= token0TotalSupply()
			&& token1Balance(a) + token1Balance(c) <= token1TotalSupply()
			&& lpBalance(a) + lpBalance(c) <= lpTotalSupply()
			&& pairERC20.balanceOf(a) + pairERC20.balanceOf(c) + pairERC20.balanceOf(pair) <= pairERC20.totalSupply()
			&& BAMMBalance(a) + BAMMBalance(c)<= BAMMTotalSupply();
	}

	if ((a != b) && (a == c || b == c)) {
		return 
			   token0Balance(a) + token0Balance(b) <= token0TotalSupply()
			&& token1Balance(a) + token1Balance(b) <= token1TotalSupply()
			&& lpBalance(a) + lpBalance(b) <= lpTotalSupply()
			&& pairERC20.balanceOf(a) + pairERC20.balanceOf(b) + pairERC20.balanceOf(pair) <= pairERC20.totalSupply()
			&& BAMMBalance(a) + BAMMBalance(b)<= BAMMTotalSupply();
	}

	if (a == b && b == c) {
		return 
			   token0Balance(a) <= token0TotalSupply()
			&& token1Balance(a) <= token1TotalSupply()
			&& lpBalance(a) <= lpTotalSupply()
			&& pairERC20.balanceOf(a) + pairERC20.balanceOf(pair) <= pairERC20.totalSupply()
			&& BAMMBalance(a) <= BAMMTotalSupply();
	}
	return false;	//should never get here

}

function safeAssumptions(env e, address user)
{
	require get_token0() != get_token1()
		&& get_token0() != get_BAMMToken()
		&& get_token0() != get_lpToken()
		&& get_token1() != get_BAMMToken()
		&& get_token1() != get_lpToken();

	require user != 0;
	require isValidVault(e, user);
	require isValidVault(e, e.msg.sender);

	require e.msg.sender != currentContract;
	require user != currentContract;

	require e.msg.sender != get_token0();
	require user != get_token0();

	require e.msg.sender != get_token1();
	require user != get_token1();

	require e.msg.sender != get_BAMMToken();
	require user != get_BAMMToken();

	require e.msg.sender != get_lpToken();
	require user != get_lpToken();

	require balanceLessThanTotalSupply(e.msg.sender, user, currentContract);
}

function differsByAtMostOne(uint256 x, mathint y) returns bool {
	if (x >= y) return x - y <= 1;
	else return y - x <= 1;
}

function noHarnessFunctions(method f){
	require f.selector != sig:get_sqrtRented().selector &&
			f.selector != sig:get_rentedMultiplier().selector &&
			f.selector != sig:get_token0().selector &&
			f.selector != sig:get_token1().selector &&
			f.selector != sig:get_lpToken().selector &&
			f.selector != sig:get_BAMMToken().selector &&
			f.selector != sig:isValidVault(IBAMM.Vault).selector &&
			f.selector != sig:isValidVault(address).selector &&
			f.selector != sig:OZmulDivTest(uint256, uint256, uint256).selector &&
			f.selector != sig:OZmulDivRoundingTest(uint256, uint256, uint256).selector &&
			f.selector != sig:OZsqrtTest(uint256).selector &&
			f.selector != sig:FMmulDivRoundingTest(uint256, uint256, uint256).selector &&
			f.selector != sig:FMmulDivTest(uint256, uint256, uint256).selector &&
			f.selector != sig:lpBalance(address).selector &&
			f.selector != sig:lpTotalSupply().selector &&
			f.selector != sig:BAMMBalance(address).selector &&
			f.selector != sig:BAMMTotalSupply().selector &&
			f.selector != sig:token0Balance(address).selector &&
			f.selector != sig:token0Balance(address).selector &&
			f.selector != sig:token1Balance(address).selector &&
			f.selector != sig:token1TotalSupply().selector &&
			f.selector != sig:get_timeSinceLastInterestPayment().selector &&
			f.selector != sig:getSqrtBalance().selector &&
			f.selector != sig:getSqrtRentedReal().selector &&
			f.selector != sig:syncVault(IBAMM.Vault, int256, uint112, uint112, uint256).selector;
}