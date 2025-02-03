import "MathSummaries.spec";

methods
{
	function version() external returns (uint256, uint256, uint256) envfree;

    //function addLiquidityUnbalanced(uint256, uint256, uint256, IFraxswapPair) external returns (uint256) envfree;
    //function estimateLiquidityUnbalanced(uint256, uint256, IFraxswapPair) external returns (uint256, int256) envfree;
    function getAmountOut_external(uint112, uint112, uint256, uint256) external returns (uint256) envfree;
	function getSwapAmount(int256, int256, int256, int256, int256) external returns (int256) envfree;
    function getSwapAmountSolve(int256,int256,int256,int256,int256) external returns (int256) envfree;

    function log2_external(int256) external returns (uint256) envfree;
	function sqrtInt_external(int256) external returns (int256) envfree;
    function sqrt_external(uint256) external returns (uint256) envfree;
    function mul_external(int256, int256) external returns (int256, uint256) envfree;
}

// violated https://prover.certora.com/output/6893/d1df21714eae4101948236efd2f721b0/?anonymousKey=69587731bbba4293104b20b9e4970fc3e33f427d
rule log2_correctness()
{
	int256 x;
	require x > 0;	// the method doesn't revert for x = 0, it returns 1 instead
	require x < 100;
	uint256 res = log2_external(x);

	assert 2^res <= x && 2^(res+1) > x;
}

// holds
rule sqrt_correctness()
{
	uint256 x;
	uint256 root = sqrt_external(x);

	assert root * root <= x && (root + 1) * (root + 1) > x;
}

// violated https://prover.certora.com/output/6893/d1df21714eae4101948236efd2f721b0/?anonymousKey=69587731bbba4293104b20b9e4970fc3e33f427d
rule mul_correctness()
{
	int256 x; int256 y;
	int256 res; uint256 div;
	res, div = mul_external(x, y);
	mathint trueRes = x * y;
	assert res == trueRes;
}

