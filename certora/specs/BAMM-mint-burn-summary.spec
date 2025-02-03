import "MathSummaries.spec";
import "../specs_fromSetup/unresolved_BAMM.spec";
import "Fraxswap_cvl.spec";
import "BAMM_auxiliary.spec";

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

// LTV not impacted by change in pair ratio
// STATUS: PASSING
rule ltvNotImpactedByChangedPairRatio(env e, address user)
{
	// Interest accrual will change ltv
	require e.block.timestamp == currentContract.timeSinceLastInterestPayment;
	safeAssumptions(e, user);

	uint256 _ltv = ltv(e, user);
	
	// havoc reserves
	havoc reserve0;
	havoc reserve1;
	
	uint256 ltv_ = ltv(e, user);

	assert _ltv == ltv_,"ltv cannot be changed due to changing reserve pair ratio";
}


// BAMM shares should not lose value unless there is bad debt
// STATUS: VIOLATED
rule bammSharesValueAlwaysIncreasesRepay(env e)
{
	uint256 _sqrtBalance = getSqrtBalance();
	uint256 _sqrtRentedReal = getSqrtRentedReal();
	uint256 _totalSupply = BammERC20.totalSupply(e);

	require _totalSupply != 0;

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

	// in order to not override repay action
	require !action.closePosition;

	// Repaying
	require action.rent < 0;

	// swap shouldn't have any effect on the BAMM share ratio
	require swapParams.amountIn == 0;

	executeActionsAndSwap(e, action, swapParams);

	uint256 sqrtBalance_ = getSqrtBalance();
	uint256 sqrtRentedReal_ = getSqrtRentedReal();
	uint256 totalSupply_ = BammERC20.totalSupply(e);

	mathint sqrtSum_ = sqrtBalance_ + sqrtRentedReal_;

	assert _sqrtSum * totalSupply_ <= sqrtSum_*_totalSupply,"BAMM shares should increase in value unless there is bad debt";
}