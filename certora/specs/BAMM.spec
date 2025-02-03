// import "MathSummaries.spec";
import "../specs_fromSetup/unresolved_BAMM.spec";
import "HardMethods_summaries.spec";
// import "FraxSwapPair_summaries.spec";
import "BAMM_auxiliary.spec";

using BAMMERC20 as BammERC20;

// mint and redeem are inverse operations
rule mintRedeemInverse(){
	address to1;
	uint256 lpIn;
	uint256 bammOut;
	env e1;
	// requiring this to make sure the bammOut is all the tokens owed for lpIn
	require BammERC20.totalSupply(e1) != 0;

	address user;
	safeAssumptions(e1, user);
	
	bammOut = mint(e1, to1, lpIn);

	env e2;
	// requiing the same timestamp to ensure no interest is accrued after mint
	require e2.block.timestamp == e1.block.timestamp;
	address to2;
	uint256 lpOut;
	lpOut = redeem(e2, to2, bammOut);

	assert lpOut <= lpIn,"same amount of lp tokens should be returned";
}

// Borrow and repay are inverse operations
// 1. Rent of the borrower returns to the same amount as before the borrow
rule borrowRepayInverseRented(){
	env e;
	IBAMM.Action borrow_action;

	require get_timeSinceLastInterestPayment() == e.block.timestamp;
	// borrowing
	require borrow_action.rent > 0;
	require !borrow_action.closePosition;
	require borrow_action.token0Amount == 0;
	require borrow_action.token1Amount == 0;
	
	int256 rented_before = currentContract.userVaults[e.msg.sender].rented;

	IFraxswapRouterMultihop.FraxswapParams swapParams_borrow;
	
	executeActionsAndSwap(e, borrow_action, swapParams_borrow);
	
	IBAMM.Action repay_action;
	// repaying borrowed amount
	require repay_action.rent == -borrow_action.rent;
	require !repay_action.closePosition;
	require repay_action.token0Amount == 0;
	require repay_action.token1Amount == 0;

	IFraxswapRouterMultihop.FraxswapParams swapParams_repay;
	executeActionsAndSwap(e, repay_action, swapParams_repay);

	int256 rented_after = currentContract.userVaults[e.msg.sender].rented;

	assert rented_after == rented_before, "rented amount before and after should be the same";
}


// BAMM shares should not lose value unless there is bad debt
// Ratio of (sqrtBalance + sqrtRentedReal)/totalSupply always increases; except for possibly bad debt liquidations.
// Borrow
rule bammSharesValueAlwaysIncreasesBorrow(env e)
{
	uint256 _sqrtBalance = getSqrtBalance();
	uint256 _sqrtRentedReal = getSqrtRentedReal();
	uint256 _totalSupply = BammERC20.totalSupply(e);

	address user;
	safeAssumptions(e, user);
	
	mathint _sqrtSum = _sqrtBalance + _sqrtRentedReal;

	IBAMM.Action action;
	IFraxswapRouterMultihop.FraxswapParams swapParams;

	// for simplification
	require action.token0Amount == 0;
	require action.token1Amount == 0;
	// assuming no interest accrual
	require get_timeSinceLastInterestPayment() == e.block.timestamp;

	// in order to not override borrow action
	require !action.closePosition;
	// borrowing
	require action.rent > 0;
	// swap shouldn't have any effect on the BAMM share ratio. Need to prove separately
	require swapParams.amountIn == 0;

	executeActionsAndSwap(e, action, swapParams);

	uint256 sqrtBalance_ = getSqrtBalance();
	uint256 sqrtRentedReal_ = getSqrtRentedReal();
	uint256 totalSupply_ = BammERC20.totalSupply(e);

	mathint sqrtSum_ = sqrtBalance_ + sqrtRentedReal_;

	assert _sqrtSum * totalSupply_ <= sqrtSum_*_totalSupply,"BAMM shares should increase in value unless there is bad debt";
}



// LTV of a user should not be changed by another user
rule ltvNotChangedByOthers(env e, address user, method f)
filtered{f -> !f.isView && !isIgnored(f) &&
f.selector != sig:microLiquidate(address).selector  &&
f.selector != sig:executeActions(IBAMM.Action).selector &&
f.selector != sig:executeActionsAndSwap(IBAMM.Action, IFraxswapRouterMultihop.FraxswapParams).selector}{
	
	// Interest accrual will change ltv
	require e.block.timestamp == currentContract.timeSinceLastInterestPayment;

	safeAssumptions(e, user);

	uint256 _ltv = ltv(e, user);
	
	calldataarg args;
	f(e, args);
	
	uint256 ltv_ = ltv(e, user);

	assert e.msg.sender != user => _ltv == ltv_,"ltv cannot be changed by someone else";
}


// ltv rule with Repay
rule ltvNotChangedByOthersRepay(env e, address user){

	safeAssumptions(e, user);

	IBAMM.Action action;
	IFraxswapRouterMultihop.FraxswapParams swapParams;

	// for simplification
	require action.token0Amount == 0;
	require action.token1Amount == 0;
	// assuming no interest accrual
	require get_timeSinceLastInterestPayment() == e.block.timestamp;

	// in order to not override repay action
	require !action.closePosition;
	// Repaying
	require action.rent < 0;
	
	// for simplicity. need to prove for the swap case separately
	require swapParams.amountIn == 0;

	uint256 _ltv = ltv(e, user);
	
	executeActionsAndSwap(e, action, swapParams);
	
	uint256 ltv_ = ltv(e, user);

	assert e.msg.sender != user => _ltv == ltv_,"ltv cannot be changed by someone else";
}

// ltv rule with borrow
rule ltvNotChangedByOthersborrow(env e, address user){

	safeAssumptions(e, user);

	IBAMM.Action action;
	IFraxswapRouterMultihop.FraxswapParams swapParams;

	// for simplification
	require action.token0Amount == 0;
	require action.token1Amount == 0;
	// assuming no interest accrual
	require get_timeSinceLastInterestPayment() == e.block.timestamp;

	// in order to not override repay action
	require !action.closePosition;
	// Repaying
	require action.rent > 0;
	
	// for simplicity. need to prove for the swap case separately
	require swapParams.amountIn == 0;

	uint256 _ltv = ltv(e, user);
	
	executeActionsAndSwap(e, action, swapParams);
	
	uint256 ltv_ = ltv(e, user);

	assert e.msg.sender != user => _ltv == ltv_,"ltv cannot be changed by someone else";
}