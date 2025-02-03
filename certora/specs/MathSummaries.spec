import "MathSummaries_noOZ.spec";

methods
{
	// OZMath

	function _.mulDiv(uint256 a, uint256 b, uint256 c, Math.Rounding rounding) internal 
	 	=> CVLmulDivRoundingUp(a, b, c) expect uint256;

}