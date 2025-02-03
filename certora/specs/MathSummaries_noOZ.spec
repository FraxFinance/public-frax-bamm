methods
{
	// FullMath
	function _.mulDivRoundingUp(uint256 a, uint256 b, uint256 c) internal 
		=> CVLmulDivRoundingUp(a, b, c) expect uint256;
		
	function _.mulDiv(uint256 a, uint256 b, uint256 c) internal => CVLmulDiv(a, b, c) expect uint256;
	function _.sqrt(uint256 x) internal => CVL_sqrt(x) expect uint256;
	// function FraxMath.sqrt(uint256 x) internal returns uint256 => CVL_sqrt(x);	// not applied !! 
	
	// LibBytes
	function _.slice(bytes memory _bytes, uint256 _start, uint256 _length) internal
		=> bytesSliceSummary(_bytes, _start, _length) expect (bytes memory) ALL;

}

function CVLmulDiv(uint256 a, uint256 b, uint256 c) returns uint256 {
	require c != 0;
	return require_uint256(a * b / c);
}

function CVLmulDivRoundingUp(uint256 a, uint256 b, uint256 c) returns uint256 {
	require c != 0;
	return  require_uint256((a * b + c - 1) / c);
}

function maxDifference(mathint x, mathint y, mathint limit) returns bool {
	if (x >= y) return x - y <= limit;
	else return y - x <= limit;
}

function CVL_sqrt(uint256 x) returns uint256 {
    mathint SQRT;
    require SQRT*SQRT <= to_mathint(x) && (SQRT + 1)*(SQRT + 1) > to_mathint(x);
    return require_uint256(SQRT);
}

ghost mapping(bytes32 => mapping(uint => bytes32)) sliceGhost;

function bytesSliceSummary(bytes buffer, uint256 start, uint256 len) returns bytes {
	bytes to_ret;
	require(to_ret.length == len);
	require(buffer.length >= require_uint256(start + len));
	bytes32 buffer_hash = keccak256(buffer);
	require keccak256(to_ret) == sliceGhost[buffer_hash][start];
	return to_ret;
}
