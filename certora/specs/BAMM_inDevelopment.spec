////////////////////////////////////////////////////
////////
//////// 	these rules are not finished yet
//////// 	they might timeout, give spurious violations, etc.
////////
////////////////////////////////////////////////////

import "../specs_fromSetup/unresolved_BAMM.spec";
import "HardMethods_summaries.spec";
import "BAMM_auxiliary.spec";
	
// too hard
rule microLiquidateDoesntCauseRevert(env e, env e2)
{
	storage init = lastStorage;
	IBAMM.Action a;
	IFraxswapRouterMultihop.FraxswapParams swapParams;
	_ = executeActionsAndSwap(e, a, swapParams);			//didn't revert before

	require e.msg.sender != e2.msg.sender;
	address user;
	microLiquidate(e2, user) at init;
	_ = executeActionsAndSwap@withrevert(e, a, swapParams);	//shouldn't revert after
	assert !lastReverted;
}

//timeout
rule mint_monotonic(env e)
{
	address recepient;
	safeAssumptions(e, recepient);
	uint lpIn1; uint lpIn2;
	require get_timeSinceLastInterestPayment() == e.block.timestamp;
	storage init = lastStorage;
	uint bammOut1 = mint(e, recepient, lpIn1);
	uint bammOut2 = mint(e, recepient, lpIn2) at init;
	
	assert lpIn1 < lpIn2 => bammOut1 <= bammOut2;
	//satisfy lpIn1 < lpIn2 && bammOut1 <= bammOut2;
}

//timeout
rule redeem_monotonic(env e)
{
	address recepient;
	safeAssumptions(e, recepient);
	uint bammIn1; uint bammIn2;
	require get_timeSinceLastInterestPayment() == e.block.timestamp;
	storage init = lastStorage;
	uint lpOut1 = redeem(e, recepient, bammIn1);
	uint lpOut2 = redeem(e, recepient, bammIn2) at init;
	
	assert bammIn1 < bammIn2 => lpOut1 <= lpOut2;
	//satisfy bammIn1 < bammIn2 && lpOut1 <= lpOut2;
}

// timeout
rule token0EqualsSumVaultToken0(method f, env e) filtered { f -> !f.isView && !isIgnored(f)}
{
	require vault_token0_change_Ghost == 0;
	mathint token0Before = token0Balance(currentContract);
	address user; uint256 amount;
	safeAssumptions(e, user);
	require get_timeSinceLastInterestPayment() == e.block.timestamp;
	//microLiquidate(e, user);
	callMethodWithArgs(e, f, user, amount);
	mathint token0After = token0Balance(currentContract);
	assert token0After == token0Before + vault_token0_change_Ghost;
}

// timeout
rule token1EqualsSumVaultToken1(method f, env e) filtered { f -> !f.isView && !isIgnored(f) }
{
	require vault_token1_change_Ghost == 0;
	mathint token1Before = token1Balance(currentContract);
	address user; uint256 amount;
	safeAssumptions(e, user);
	require get_timeSinceLastInterestPayment() == e.block.timestamp;
	//microLiquidate(e, user);
	callMethodWithArgs(e, f, user, amount);
	mathint token1After = token1Balance(currentContract);
	assert token1After == token1Before + vault_token1_change_Ghost;
}

// This should be true for _syncvault return values
// token0Amount / reserve0 == token1Amount / reserve1
// can be rewritten to |token0Amount * reserve1 - token1Amount * reserve0| < reserve0 * reverse1
// timeout
rule syncVault_correctness(env e)
{
	address user; int256 _rent; uint112 _reserve0;
	uint112 _reserve1;
	uint _pairTotalSupply = lpTotalSupply();
	safeAssumptions(e, user);
	int256 token0Amount; int256 token1Amount;
	(_, token0Amount, token1Amount) = syncVault(e, user, _rent, _reserve0,
		_reserve1, _pairTotalSupply);
	
	//assert token0Amount / _reserve0 == token1Amount / _reserve1;
	assert maxDifference(token0Amount * _reserve1, token1Amount * _reserve0, _reserve0 * _reserve1);
}

// _syncVault returns lpTokenAmount for a given vault should always be 
// less then IERC20(address(pair)).balanceof(BAMM)
// violated - probably a wrong property
rule _syncVaultNeverExceedsBammBalance(env e)
{
	IBAMM.Vault vault; int256 _rent; uint112 _reserve0;
	uint112 _reserve1;
	uint _pairTotalSupply = lpTotalSupply();
	require isValidVault(e, vault);
	int256 lpTokenAmount;
	(lpTokenAmount, _, _) = syncVault(e, vault, _rent, _reserve0,
		_reserve1, _pairTotalSupply);
	assert lpTokenAmount <= lpBalance(currentContract); 
}