
import "../specs_fromSetup/unresolved_BAMM.spec";
import "HardMethods_summaries.spec";
import "BAMM_auxiliary.spec";

// BAMM.rentedMultiplier doesn't decrease via any method call
rule rentedMultiplier_neverDecreases(method f, env e) filtered { f -> !f.isView && !isIgnored(f)}
{
	mathint multiplierBefore = get_rentedMultiplier();
	uint amount; address user;
	safeAssumptions(e, user);
	//microLiquidate(e, user);
	callMethodWithArgs(e, f, user, amount);
	mathint multiplierAfter = get_rentedMultiplier();
	assert multiplierAfter >= multiplierBefore;
	satisfy multiplierAfter >= multiplierBefore;
}

// the same as above only for the microLiquidate method
rule rentedMultiplier_neverDecreases_microLiquidate(env e)
{
	mathint multiplierBefore = get_rentedMultiplier();
	address user;
	safeAssumptions(e, user);
	microLiquidate(e, user);
	mathint multiplierAfter = get_rentedMultiplier();
	assert multiplierAfter >= multiplierBefore;
	satisfy multiplierAfter >= multiplierBefore;
}
	
// BAMM.sqrtRented == SUM[vault.rented] over all vaults
rule sqrtRentedEqualsSumVaultRented(method f, env e) filtered { f -> !f.isView && !isIgnored(f)}
{
	require vault_Rented_change_Ghost == 0;
	mathint sqrtRentedBefore = get_sqrtRented();
	address user; uint256 amount;
	safeAssumptions(e, user);
	callMethodWithArgs(e, f, user, amount);
	mathint sqrtRentedAfter = get_sqrtRented();
	assert sqrtRentedAfter == sqrtRentedBefore + vault_Rented_change_Ghost;
}

// BAMM.sqrtRented >= 0 at any time
rule sqrtRented_neverLTzero(env e, method f) filtered { f -> !f.isView && !isIgnored(f)}
{
	require get_sqrtRented() >= 0;
	uint amount;
	address user;
	safeAssumptions(e, user);
	callMethodWithArgs(e, f, user, amount);
	satisfy get_sqrtRented() >= 0;
	assert get_sqrtRented() >= 0;
}

// vault.isValid() is true at any time
invariant vaultRemainsValid(address user, env e)
	isValidVault(e, user)
	filtered { f -> !f.isView && !isIgnored(f)
}

// Redeem(Mint(x)) <= x
rule mint_redeem_notProfitable(env e)
{
	address recepient;
	safeAssumptions(e, recepient);
	uint lpIn;
	uint bammOut = mint(e, recepient, lpIn);
	uint256 lpOut = redeem(e, recepient, bammOut);

	assert lpOut <= lpIn;
	//assert lpOut + 2 >= lpIn;
}

// If bammOut = mint(recepient, lpIn) then
//	- BAMM balance of recepient increases by bammOut
//	- lp balance of msg.sender decreases by lpIn
// as long as there is no interest added
rule mint_integrity(env e)
{
	address recepient;
	safeAssumptions(e, recepient);
	uint lpBalanceBefore = lpBalance(e.msg.sender);
	uint BAMMBalanceBefore = BAMMBalance(recepient);
	uint lpIn;
	require get_timeSinceLastInterestPayment() == e.block.timestamp;
	uint bammOut = mint(e, recepient, lpIn);
	uint lpBbalanceAfter = lpBalance(e.msg.sender);
	uint BAMMBalanceAfter = BAMMBalance(recepient);

	assert lpBbalanceAfter == lpBalanceBefore - lpIn;
	assert BAMMBalanceAfter == BAMMBalanceBefore + bammOut;
}

// calling mint(recepient, lpIn) doesn't affect balances of any token
// of any user except recepient, msg.sender and the BAMM contract
rule mint_doesntAffectOthers(env e)
{
	address recepient;
	address other;
	safeAssumptions(e, recepient);
	safeAssumptions(e, other);
	require other != recepient && other != e.msg.sender;
	require get_timeSinceLastInterestPayment() == e.block.timestamp;

	uint lpBalanceBefore = lpBalance(other);
	uint BAMMBalanceBefore = BAMMBalance(other);
	uint lpIn;
	uint bammOut = mint(e, recepient, lpIn);
	uint lpBbalanceAfter = lpBalance(other);
	uint BAMMBalanceAfter = BAMMBalance(other);

	assert lpBbalanceAfter == lpBbalanceAfter;
	assert BAMMBalanceAfter == BAMMBalanceBefore;
}

// If lpOut = redeem(recepient, bammIn) then
//	- BAMM balance of msg.sender decreases by bammIn
//	- lp balance of recepient increases at least by lpOut-1
// as long as there is no interest added
rule redeem_integrity(env e)
{
	address recepient;
	safeAssumptions(e, recepient);
	uint lpBalanceBefore = lpBalance(recepient);
	uint BAMMBalanceBefore = BAMMBalance(e.msg.sender);
	uint bammIn;
	require get_timeSinceLastInterestPayment() == e.block.timestamp;	// to avoid interest
	uint lpOut = redeem(e, recepient, bammIn);
	mathint lpBbalanceAfter = lpBalance(recepient);
	uint BAMMBalanceAfter = BAMMBalance(e.msg.sender);

	//assert lpBbalanceAfter == lpBalanceBefore + lpOut;
	assert maxDifference(lpBbalanceAfter, lpBalanceBefore + lpOut, 1);
	assert BAMMBalanceAfter == BAMMBalanceBefore - bammIn;
}

// calling redeem(recepient, bammIn) doesn't affect balances of any token
// of any user except recepient, msg.sender and the BAMM contract
rule redeem_doesntAffectOthers(env e)
{
	address recepient; address other;
	safeAssumptions(e, recepient);
	safeAssumptions(e, other);
	require other != recepient && other != e.msg.sender;
	require get_timeSinceLastInterestPayment() == e.block.timestamp;

	uint lpBalanceBefore = lpBalance(other);
	uint BAMMBalanceBefore = BAMMBalance(other);
	uint bammIn;
	uint lpOut = redeem(e, recepient, bammIn);
	uint lpBbalanceAfter = lpBalance(other);
	uint BAMMBalanceAfter = BAMMBalance(other);

	assert lpBbalanceAfter == lpBbalanceAfter;
	assert BAMMBalanceAfter == BAMMBalanceBefore;
}	