methods
{
	function mostSignificantBit(uint256) external returns (uint8) envfree;
	function leastSignificantBit(uint256) external returns (uint8) envfree;
}

rule msb_Correctness() {
	uint x;
	require x > 0;
	uint8 res = mostSignificantBit(x);
	assert x >= 2^res && x < 2^(res + 1);
}

// (x & 2**lsb) != 0 and (x & (2**(lsb) - 1)) == 0)
rule lsb_Correctness() {
	uint x;
	require x > 0;
	uint8 res = leastSignificantBit(x);
	uint pow = assert_uint256(2^res);
	uint pow_minus_one = assert_uint256(pow - 1);
	assert x & pow != 0 && x & pow_minus_one == 0;
}

rule msb_neverReverts() {
	uint x;
	require x > 0;
	uint8 res = mostSignificantBit@withrevert(x);
	assert !lastReverted;
}

rule lsb_neverReverts() {
	uint x;
	require x > 0;
	uint8 res = leastSignificantBit@withrevert(x);
	assert !lastReverted;
}
