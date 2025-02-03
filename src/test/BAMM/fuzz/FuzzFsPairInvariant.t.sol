import "../../BaseTest.t.sol";
import "../../helpers/BAMMTestHelper.sol";
import { FraxswapPair } from "dev-fraxswap/src/contracts/core/FraxswapPair.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract FuzzFraxSwapFeeGrowth is BaseTest, BAMMTestHelper {
    address swapper = address(0x494949);

    function setUp() public {
        vm.createSelectFork(vm.envString("MAINNET_RPC_URL"));
        defaultSetup();
        _createFreshBamm();
        _mintLP(1000e18);
    }

    function _mintLP(uint256 lp) public {
        address minter = address(2322);
        uint256 lpBalBefore = iPair.balanceOf(minter);

        uint256 ts = iPair.totalSupply();
        (uint256 token0InPair, uint256 token1InPair, ) = iPair.getReserves();

        uint256 tkn0 = ((lp * token0InPair) / ts);
        uint256 tkn1 = ((lp * token1InPair) / ts);

        deal(address(iToken0), minter, tkn0);
        deal(address(iToken1), minter, tkn1);

        console.log("       tkn0: ", tkn0);
        console.log("       tkn1: ", tkn1);

        vm.startPrank(minter);
        iToken0.transfer(address(iPair), tkn0);
        iToken1.transfer(address(iPair), tkn1);
        iPair.mint(minter);
        vm.stopPrank();

        console.log("_mintLP: The balance minted: ", iPair.balanceOf(minter) - lpBalBefore);
    }

    /// @notice Fuzz Fraxswap pair and check that the growth in (rootK / LP) is equivalent to
    ///         the fee increase in the reserves
    function test_fraxswapPairInvariant(uint96 tkn0, uint96 tkn1) public {
        vm.assume(tkn0 > 0.0005e18);
        vm.assume(tkn1 > 0.0005e18);
        if (tkn0 > tkn1) tkn1 = 0;
        if (tkn1 > tkn1) tkn0 = 0;
        (uint256 resA, uint256 resB, ) = iPair.getReserves();
        uint256 lpVirtualPriceRootK;
        if (tkn0 > 0) {
            deal(address(iToken0), swapper, tkn0);
            vm.startPrank(swapper);

            uint256 out = iPair.getAmountOut(tkn0, address(iToken0));

            iToken0.transfer(address(iPair), tkn0);
            iPair.swap(0, out, address(swapper), hex"");

            lpVirtualPriceRootK = solveFeeGrowthRootK(resA, resB, tkn0, 0);
        } else if (tkn1 > 0) {
            deal(address(iToken1), swapper, tkn1);
            vm.startPrank(swapper);

            uint256 out = iPair.getAmountOut(tkn1, address(iToken1));

            iToken1.transfer(address(iPair), tkn1);
            iPair.swap(out, 0, address(swapper), hex"");

            lpVirtualPriceRootK = solveFeeGrowthRootK(resA, resB, 0, tkn1);
        }

        (resA, resB, ) = iPair.getReserves();
        console.log(resA, resB);
        console.log(iPair.totalSupply());
        uint256 ts = iPair.totalSupply();
        console.log(lpVirtualPriceRootK);
        assertApproxEqAbs({
            a: (Math.sqrt(resA * resB) * 1e18) / ts,
            b: lpVirtualPriceRootK,
            err: "// THEN: expected VP for LP not expected",
            maxDelta: 1e5
        });
    }

    function solveFeeGrowthRootK(uint256 x_0, uint256 y_0, uint256 x_in, uint256 y_in) public pure returns (uint256) {
        if (x_in > 0 && y_in == 0) {
            return Math.sqrt(((x_0 + x_in) * 1e36) / (x_0 + ((9970 * x_in) / 10_000)));
        }
        if (x_in == 0 && y_in > 0) {
            return Math.sqrt(((y_0 + y_in) * 1e36) / (y_0 + ((9970 * y_in) / 10_000)));
        }
    }
}
