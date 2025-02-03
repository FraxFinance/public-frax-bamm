// only testing rules here and helper methods / definitions

methods
{
	// harness methods declared envfree
	function get_sqrtRented() external returns (int256) envfree;
	function get_rentedMultiplier() external returns (uint256) envfree;
	function getSqrtBalance() external returns (uint256) envfree;
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
	function getVault_Rented(address user) external returns (int256) envfree;
	function getVault_token0(address user) external returns (int256) envfree;
	function getVault_token1(address user) external returns (int256) envfree;
	function getMaxSell(uint256 tokenIn, uint256 tokenOut,
        uint256 reserveIn, uint256 reserveOut) external returns (uint256) envfree;

	function get_timeSinceLastInterestPayment() external returns (uint256) envfree;


}

// for testing only
rule testSummary(env e)
{
	uint256 a; uint256 b; uint256 c;
	uint res1 = OZsqrtTest(e, a);
	uint res2 = OZmulDivTest(e, a,b,c);
	uint res3 = OZmulDivRoundingTest(e, a,b,c);
	uint res4 = FMmulDivTest(e, a,b,c);
	uint res5 = FMmulDivRoundingTest(e, a,b,c);
	uint res6 = FMsqrtTest(e, a);

	satisfy res1 != 0;
	satisfy res2 != 0;
	satisfy res3 != 0;
	satisfy res4 != 0;
	satisfy res5 != 0;
	satisfy res6 != 0;
}

// for testing only
rule doesntAlwaysRevert(method f, env e)
{
	calldataarg args;
	f(e, args);
	satisfy true;
}

// for testing only
rule addInterest_satisfy(env e)
{
	uint256 reserve0; uint256 reserve1; uint256 pairTotalSupply; uint256 _rentedMultiplier;
	reserve0, reserve1, pairTotalSupply, _rentedMultiplier = addInterest(e);
	satisfy true;
}

// for testing only
rule microLiquidate_satisfy(env e)
{
	address user;
	microLiquidate(e, user);
	satisfy true;
}

// for testing only
rule getMaxSellSummary_test()
{
	uint256 tokenIn; uint256 tokenOut;
    uint256 reserveIn; uint256 reserveOut;
	uint resReal = getMaxSell(tokenIn, tokenOut, reserveIn, reserveOut);
        
	uint resSummary = simpleGetMaxSell(tokenIn, tokenOut, reserveIn, reserveOut);
	assert maxDifference(resReal, resSummary, 1);
}

ghost mathint vault_Rented_change_Ghost;
hook Sstore userVaults[KEY address user].rented int256 newRented (int256 oldRented) {
    vault_Rented_change_Ghost = vault_Rented_change_Ghost + newRented - oldRented;
}

ghost mathint vault_token0_change_Ghost;
hook Sstore userVaults[KEY address user].token0 int256 newValue (int256 oldValue) {
    vault_token0_change_Ghost = vault_token0_change_Ghost + newValue - oldValue;
}

ghost mathint vault_token1_change_Ghost;
hook Sstore userVaults[KEY address user].token1 int256 newValue (int256 oldValue) {
    vault_token1_change_Ghost = vault_token1_change_Ghost + newValue - oldValue;
}

// A manual method dispatcher that allows to put constrains on some of the arguments.
// Works for all public non-view methods
function callMethodWithArgs(env e, method f, address to, uint256 amount)
{
	if (f.selector == sig:redeem(address,uint256).selector)	{ redeem(e, to, amount); }
	else if (f.selector == sig:mint(address,uint256).selector) {	mint(e, to, amount); }
	else if (f.selector == sig:microLiquidate(address).selector) { microLiquidate(e, to); }
	else if (f.selector == sig:addInterest().selector) { addInterest(e); }
	else if (f.selector == sig:addToken0(uint256, address).selector) { 
		IBAMM.Action action;
		require action.to == to;
		require action.token0Amount == amount;
		require action.token1Amount == 0;
		require action.rent == 0;
		require action.closePosition == false;
		executeActions(e, action);
	}
	else if (f.selector == sig:addToken1(uint256, address).selector) { 
		IBAMM.Action action;
		require action.to == to;
		require action.token1Amount == amount;
		require action.token0Amount == 0;
		require action.rent == 0;
		require action.closePosition == false;
		executeActions(e, action);
	}
	else if (f.selector == sig:removeToken0(uint256, address).selector) { 
		IBAMM.Action action;
		require action.to == to;
		require action.token0Amount == -amount;
		require action.token1Amount == 0;
		require action.rent == 0;
		require action.closePosition == false;
		executeActions(e, action);
	}
	else if (f.selector == sig:removeToken1(uint256, address).selector) { 
		IBAMM.Action action;
		require action.to == to;
		require action.token1Amount == -amount;
		require action.token0Amount == 0;
		require action.rent == 0;
		require action.closePosition == false;
		executeActions(e, action);
	}
	else if (f.selector == sig:borrow(uint256, address).selector) { 
		IBAMM.Action action;
		require action.to == to;
		require action.token0Amount == 0;
		require action.token1Amount == 0;
		require action.rent == amount;
		require action.closePosition == false;
		executeActions(e, action);
	}
	else if (f.selector == sig:repay(uint256, address).selector) { 
		IBAMM.Action action;
		require action.to == to;
		require action.token1Amount == 0;
		require action.token0Amount == 0;
		require action.rent == amount;
		require action.closePosition == false;
		executeActions(e, action);
	}
	else if (f.selector == sig:swapToken0(uint256, address).selector) { 
		IBAMM.Action action;
		IFraxswapRouterMultihop.FraxswapParams swapParams;
		require action.to == to;
		require action.token1Amount == 0;
		require action.token0Amount == 0;
		require action.rent == 0;
		require action.closePosition == false;
		        
        require swapParams.recipient == to;
        require swapParams.tokenIn == get_token0();
        require swapParams.tokenOut == get_token1();
        require swapParams.amountIn == amount;
		executeActionsAndSwap(e, action, swapParams);
	}
	else if (f.selector == sig:swapToken1(uint256, address).selector) { 
		IBAMM.Action action;
		IFraxswapRouterMultihop.FraxswapParams swapParams;
		require action.to == to;
		require action.token1Amount == 0;
		require action.token0Amount == 0;
		require action.rent == 0;
		require action.closePosition == false;
		        
        require swapParams.recipient == to;
        require swapParams.tokenIn == get_token1();
        require swapParams.tokenOut == get_token0();
        require swapParams.amountIn == amount;
		executeActionsAndSwap(e, action, swapParams);
	}
	else if (f.selector == sig:executeActionsAndSwap(IBAMM.Action,IFraxswapRouterMultihop.FraxswapParams).selector) {
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
			&& BAMMBalance(a) + BAMMBalance(b) + BAMMBalance(c)<= BAMMTotalSupply();
	}
	
	if (a == b && a != c) {
		return 
			   token0Balance(a) + token0Balance(c) <= token0TotalSupply()
			&& token1Balance(a) + token1Balance(c) <= token1TotalSupply()
			&& lpBalance(a) + lpBalance(c) <= lpTotalSupply()
			&& BAMMBalance(a) + BAMMBalance(c)<= BAMMTotalSupply();
	}

	if ((a != b) && (a == c || b == c)) {
		return 
			   token0Balance(a) + token0Balance(b) <= token0TotalSupply()
			&& token1Balance(a) + token1Balance(b) <= token1TotalSupply()
			&& lpBalance(a) + lpBalance(b) <= lpTotalSupply()
			&& BAMMBalance(a) + BAMMBalance(b)<= BAMMTotalSupply();
	}

	if (a == b && b == c) {
		return 
			   token0Balance(a) <= token0TotalSupply()
			&& token1Balance(a) <= token1TotalSupply()
			&& lpBalance(a) <= lpTotalSupply()
			&& BAMMBalance(a) <= BAMMTotalSupply();
	}
	return false;	//should never get here

}

function safeAssumptions(env e, address user)
{
	require get_rentedMultiplier(e) >= 10^18;	// it starts on this value and it can only increase

	require get_token0() != get_token1()
		&& get_token0() != get_BAMMToken()
		&& get_token0() != get_lpToken()
		&& get_token1() != get_BAMMToken()
		&& get_token1() != get_lpToken();

	require user != 0;
	require isValidVault(e, user);			// we proved this. its safe to assume
	require isValidVault(e, e.msg.sender);	// we proved this. its safe to assume

	// we can safely assume these since we proved vaultIsValid, hence vault.rented >= 0
	// and we proved sqrt.rented == sum[vault.rented] over all vaults.
	// hence sqrtRented must be at least sum of vault.rented over any subset of vaults.
	require get_sqrtRented() >= getVault_Rented(user);
	require get_sqrtRented() >= getVault_Rented(e.msg.sender);
	require user != e.msg.sender => get_sqrtRented() >= getVault_Rented(e.msg.sender) + getVault_Rented(user);

	// we can safely assume these too for the same reasons as above
	require token0Balance(currentContract) >= getVault_token0(user);
	require token0Balance(currentContract) >= getVault_token0(e.msg.sender);
	require user != e.msg.sender => token0Balance(currentContract) 
		>= getVault_token0(user) + getVault_token0(e.msg.sender);

	require token1Balance(currentContract) >= getVault_token1(user);
	require token1Balance(currentContract) >= getVault_token1(e.msg.sender);
	require user != e.msg.sender => token1Balance(currentContract) 
		>= getVault_token1(user) + getVault_token1(e.msg.sender);

	require e.msg.sender != currentContract;
	require user != currentContract;			// this might be unsafe.

	require e.msg.sender != 1;
	require user != 1;

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

definition isIgnored(method f) returns bool =
	isHarnessMethod(f) 
	//|| f.selector == sig:executeActionsAndSwap(IBAMM.Action,IFraxswapRouterMultihop.FraxswapParams).selector // this is replaced by specific-action methods
	|| f.selector == sig:executeActions(IBAMM.Action).selector;					//special case of execuetAcitionsAndSwap
	// f.selector != sig:microLiquidate(address).selector;
	//|| f.selector == sig:borrow(uint256,address).selector
	//|| f.selector == sig:repay(uint256,address).selector;

definition isHarnessMethod(method f) returns bool =
	f.selector == sig:syncVault(IBAMM.Vault, int256, uint112, uint112, uint256).selector 			
	|| f.selector == sig:syncVault(address, int256, uint112, uint112, uint256).selector 
	|| f.selector == sig:get_sqrtRented().selector 
	|| f.selector == sig:get_rentedMultiplier().selector 
	|| f.selector == sig:get_token0().selector 
	|| f.selector == sig:get_token1().selector 
	|| f.selector == sig:get_lpToken().selector 
	|| f.selector == sig:get_BAMMToken().selector 
	|| f.selector == sig:isValidVault(IBAMM.Vault).selector
	|| f.selector == sig:isValidVault(address).selector
	|| f.selector == sig:getVault_Rented(address).selector
	|| f.selector == sig:getVault_token0(address).selector
	|| f.selector == sig:getVault_token1(address).selector
	|| f.selector == sig:OZmulDivTest(uint256, uint256, uint256).selector
	|| f.selector == sig:OZmulDivRoundingTest(uint256, uint256, uint256).selector
	|| f.selector == sig:OZsqrtTest(uint256).selector
	|| f.selector == sig:FMsqrtTest(uint256).selector
	|| f.selector == sig:FMmulDivRoundingTest(uint256, uint256, uint256).selector
	|| f.selector == sig:FMmulDivTest(uint256, uint256, uint256).selector
	|| f.selector == sig:lpBalance(address).selector
	|| f.selector == sig:lpTotalSupply().selector
	|| f.selector == sig:BAMMBalance(address).selector
	|| f.selector == sig:BAMMTotalSupply().selector
	|| f.selector == sig:token0Balance(address).selector
	|| f.selector == sig:token0TotalSupply().selector
	|| f.selector == sig:token1Balance(address).selector
	|| f.selector == sig:token1TotalSupply().selector
	|| f.selector == sig:get_timeSinceLastInterestPayment().selector
	|| f.selector == sig:getSqrtBalance().selector
	|| f.selector == sig:getSqrtReserve().selector
	|| f.selector == sig:getSqrtRentedReal().selector
	|| f.selector == sig:addToken0(uint256, address).selector
	|| f.selector == sig:removeToken0(uint256, address).selector
	|| f.selector == sig:addToken1(uint256, address).selector
	|| f.selector == sig:removeToken1(uint256, address).selector
	|| f.selector == sig:borrow(uint256, address).selector
	|| f.selector == sig:repay(uint256, address).selector
	|| f.selector == sig:swapToken0(uint256, address).selector
	|| f.selector == sig:swapToken1(uint256, address).selector;
	
