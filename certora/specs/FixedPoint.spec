import "MathSummaries_noOZ.spec";

methods
{
	function encode(uint112) external returns (FixedPoint.uq112x112) envfree;
	function encode144(uint144) external returns (FixedPoint.uq144x112) envfree;
	function decode(FixedPoint.uq112x112) external returns (uint112) envfree;
	function decode144(FixedPoint.uq144x112) external returns (uint144) envfree;
	function mul(FixedPoint.uq112x112, uint256) external returns (FixedPoint.uq144x112) envfree;
	function muli(FixedPoint.uq112x112, int256) external returns (int256) envfree;
	function muluq(FixedPoint.uq112x112, FixedPoint.uq112x112) external returns (FixedPoint.uq112x112) envfree;
	function divuq(FixedPoint.uq112x112, FixedPoint.uq112x112) external returns (FixedPoint.uq112x112) envfree;
	function fraction(uint256, uint256) external returns (FixedPoint.uq112x112) envfree;
	function reciprocal(FixedPoint.uq112x112) external returns (FixedPoint.uq112x112) envfree;
	function sqrt(FixedPoint.uq112x112) external returns (FixedPoint.uq112x112) envfree;
}

rule encodeDecode_Identity()
{
	uint112 x;
	FixedPoint.uq112x112 encoded = encode(x);
	uint112 decoded = decode(encoded);
	assert x == decoded;
	satisfy x == decoded;
}

rule sqrt_mul_correspondence()
{
	FixedPoint.uq112x112 x;
	FixedPoint.uq112x112 root = sqrt(x);
	FixedPoint.uq112x112 squared = muluq(root, root);
	assert decode(squared) <= decode(x);
	satisfy decode(squared) <= decode(x);
}

rule sqrt_correctBounds()
{
	FixedPoint.uq112x112 x;
	FixedPoint.uq112x112 root = sqrt(x);
	uint112 decodedX = decode(x);
	uint112 decodedRoot = decode(root);
	assert decodedRoot * decodedRoot <= decodedX 
		&& (decodedRoot + 1) * (decodedRoot + 1) > decodedX;
	satisfy decodedRoot * decodedRoot <= decodedX;
}

rule muluq_correctBounds()
{
	FixedPoint.uq112x112 x; FixedPoint.uq112x112 y;
	FixedPoint.uq112x112 res = muluq(x, y);
	uint112 decodedX = decode(x);
	uint112 decodedY = decode(y);
	uint112 decodedRes = decode(res);
	assert decodedX * decodedY <= decodedRes 
		&& (decodedX + 1) * (decodedY + 1) > decodedRes;
	satisfy decodedX * decodedY <= decodedRes;
}

rule divuq_correctBounds()
{
	FixedPoint.uq112x112 x; FixedPoint.uq112x112 y;
	FixedPoint.uq112x112 res = divuq(x, y);
	uint112 decodedX = decode(x);
	uint112 decodedY = decode(y);
	require decodedY > 0;
	uint112 decodedRes = decode(res);
	assert decodedX / (decodedY + 1) <= decodedRes 
		&& (decodedX + 1) / decodedY >= decodedRes;
	satisfy decodedX / (decodedY + 1) <= decodedRes;
}

