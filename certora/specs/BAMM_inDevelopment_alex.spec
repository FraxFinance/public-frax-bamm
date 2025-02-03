import "MathSummaries.spec";
import "../specs_fromSetup/unresolved_BAMM.spec";
import "FraxSwapPair_summaries.spec";
import "BAMM_auxiliary.spec";

using BAMMERC20 as BammERC20;
using FraxswapPair as pair;
using BAMMFactory as BAMMFactory;

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

	function get_timeSinceLastInterestPayment() external returns (uint256) envfree;

	function _.getMaxSell(uint256, uint256, uint256, uint256) internal => NONDET ALL;
}


// BAMM shares should not lose value unless there is bad debt
// Ratio of (sqrtBalance + sqrtRentedReal)/totalSupply always increases; except for possibly bad debt liquidations.
// mint
// STATUS: TIMEOUT
rule bammSharesValueAlwaysIncreasesMint(env e){

	uint256 _sqrtBalance = getSqrtBalance();
	uint256 _sqrtRentedReal = getSqrtRentedReal();
	uint256 _totalSupply = BammERC20.totalSupply(e);

	require _totalSupply != 0;

	mathint _sqrtSum = _sqrtBalance + _sqrtRentedReal;

	address user;
	uint256 lpIn;

	safeAssumptions(e, user);

	mint(e, user, lpIn);

	uint256 sqrtBalance_ = getSqrtBalance();

	uint256 sqrtRentedReal_ = getSqrtRentedReal();

	uint256 totalSupply_ = BammERC20.totalSupply(e);

	mathint sqrtSum_ = sqrtBalance_ + sqrtRentedReal_;

	assert _sqrtSum * totalSupply_ <= sqrtSum_*_totalSupply,"BAMM shares should increase in value unless there is bad debt";
}

// BAMM shares should not lose value unless there is bad debt
// Ratio of (sqrtBalance + sqrtRentedReal)/totalSupply always increases; except for possibly bad debt liquidations.
// redeem
// STATUS: TIMEOUT
rule bammSharesValueAlwaysIncreasesRedeem(env e){

	uint256 _sqrtBalance = getSqrtBalance();
	uint256 _sqrtRentedReal = getSqrtRentedReal();
	uint256 _totalSupply = BammERC20.totalSupply(e);

	require _totalSupply != 0;

	mathint _sqrtSum = _sqrtBalance + _sqrtRentedReal;

	address user;
	uint256 bammIn;

	safeAssumptions(e, user);

	redeem(e, user, bammIn);

	uint256 sqrtBalance_ = getSqrtBalance();

	uint256 sqrtRentedReal_ = getSqrtRentedReal();

	uint256 totalSupply_ = BammERC20.totalSupply(e);

	mathint sqrtSum_ = sqrtBalance_ + sqrtRentedReal_;

	assert _sqrtSum * totalSupply_ <= sqrtSum_*_totalSupply,"BAMM shares should increase in value unless there is bad debt";
}

// BAMM shares should not lose value unless there is bad debt
// Ratio of (sqrtBalance + sqrtRentedReal)/totalSupply always increases; except for possibly bad debt liquidations.
// addInterest
// STATUS: TIMEOUT
rule bammSharesValueAlwaysIncreasesAddInterest(env e){

	uint256 _sqrtBalance = getSqrtBalance();
	uint256 _sqrtRentedReal = getSqrtRentedReal();
	uint256 _totalSupply = BammERC20.totalSupply(e);

	require _totalSupply != 0;

	mathint _sqrtSum = _sqrtBalance + _sqrtRentedReal;

	address user;

	safeAssumptions(e, user);

	addInterest(e);
	
	uint256 rentedMultiplier_ = currentContract.rentedMultiplier;
	// require rentedMultiplier_ != _rentedMultiplier;

	uint256 sqrtBalance_ = getSqrtBalance();

	uint256 sqrtRentedReal_ = getSqrtRentedReal();

	uint256 totalSupply_ = BammERC20.totalSupply(e);

	mathint sqrtSum_ = sqrtBalance_ + sqrtRentedReal_;

	assert _sqrtSum * totalSupply_ <= sqrtSum_*_totalSupply,"BAMM shares should increase in value unless there is bad debt";
}

// BAMM shares should not lose value unless there is bad debt
// Ratio of (sqrtBalance + sqrtRentedReal)/totalSupply always increases; except for possibly bad debt liquidations.
// microLiquidate
// STATUS: TIMEOUT
rule bammSharesValueAlwaysIncreasesMicroLiquidate(env e){

	uint256 _sqrtBalance = getSqrtBalance();
	uint256 _sqrtRentedReal = getSqrtRentedReal();
	uint256 _totalSupply = BammERC20.totalSupply(e);

	require _totalSupply != 0;
	
	mathint _sqrtSum = _sqrtBalance + _sqrtRentedReal;

	address user;

	safeAssumptions(e, user);

	microLiquidate(e, user);

	uint256 sqrtBalance_ = getSqrtBalance();

	uint256 sqrtRentedReal_ = getSqrtRentedReal();

	uint256 totalSupply_ = BammERC20.totalSupply(e);

	mathint sqrtSum_ = sqrtBalance_ + sqrtRentedReal_;

	assert _sqrtSum * totalSupply_ <= sqrtSum_*_totalSupply,"BAMM shares should increase in value unless there is bad debt";
}