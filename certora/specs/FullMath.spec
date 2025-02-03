methods
{
	function mulDiv(uint256, uint256, uint256) external returns (uint256) envfree;
	function mulDivRoundingUp(uint256, uint256, uint256) external returns (uint256) envfree;
}

rule mulDiv_Correctness() {
	uint a; uint b; uint c;
	uint res = mulDiv(a, b, c);
	mathint trueRes = a * b / c;
	assert res == trueRes;
}

rule mulDivRoundingUp_Correctness() {
	uint a; uint b; uint c;
	uint res = mulDivRoundingUp(a, b, c);
	mathint trueRes = (a * b + c - 1) / c;
	assert res == trueRes;
}

// todo add revert conditions