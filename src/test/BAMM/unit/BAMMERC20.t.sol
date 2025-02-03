// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import "../../helpers/BAMMTestHelper.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";

contract BAMMERC20Test is BAMMTestHelper {
    using Strings for uint256;

    function setUp() public virtual {
        defaultSetup();
    }

    function test_initialState() public {
        _createFreshBamm();

        uint256 id = iBammFactory.bammsLength() - 1;

        bytes memory ticker = abi.encodePacked(iToken0.symbol(), "/", iToken1.symbol());
        bytes memory name = abi.encodePacked("BAMM_", id.toString(), "_", ticker, " Fraxswap V2");
        bytes memory symbol = abi.encodePacked("BAMM_", ticker);

        assertEq({ a: abi.encodePacked(iBammErc20.name()), b: name, err: "name incorrect" });

        assertEq({ a: abi.encodePacked(iBammErc20.symbol()), b: symbol, err: "symbol incorrect" });

        assertEq({ a: iBammErc20.owner(), b: bamm, err: "owner incorrect" });
    }

    function test_MintAndBurn_succeeds() public {
        _createFreshBamm();

        vm.startPrank(bamm);
        iBammErc20.mint(address(1), 1e18);
        iBammErc20.burn(address(1), 1e18);
        // succeeds
    }

    function test_dynamic_symbol() public virtual {
        string memory symbolInitial = iBammErc20.symbol();
        string memory nameInitial = iBammErc20.name();

        assertEq({ a: symbolInitial, b: "BAMM_FRAX/WETH", err: "// THEN: Name not as expected" });
        assertEq({ a: nameInitial, b: "BAMM_0_FRAX/WETH Fraxswap V2", err: "// THEN: Name not as expected" });

        vm.mockCall(address(iToken0), abi.encodeWithSignature("symbol()"), abi.encode("frxUSD"));

        string memory symbolModified = iBammErc20.symbol();
        string memory nameModified = iBammErc20.name();

        assertEq({ a: symbolModified, b: "BAMM_frxUSD/WETH", err: "// THEN: Modified name not as expected" });
        assertEq({
            a: nameModified,
            b: "BAMM_0_frxUSD/WETH Fraxswap V2",
            err: "// THEN: Modified name not as expected"
        });

        vm.mockCall(address(iToken1), abi.encodeWithSignature("symbol()"), abi.encode("frxETH"));

        symbolModified = iBammErc20.symbol();
        nameModified = iBammErc20.name();

        assertEq({ a: symbolModified, b: "BAMM_frxUSD/frxETH", err: "// THEN: Modified name not as expected" });
        assertEq({
            a: nameModified,
            b: "BAMM_0_frxUSD/frxETH Fraxswap V2",
            err: "// THEN: Modified name not as expected"
        });
    }

    function test_sigs_work_if_name_symbol_dynamically_change() public {
        _initSigBammToken();
        sigUtils = new SigUtils(ERC20Permit(address(iBammErc20)).DOMAIN_SEPARATOR());
        deal(address(iBammErc20), sigTester, 100e18);

        SigUtils.Permit memory permit = SigUtils.Permit({
            owner: sigTester,
            spender: freshUser,
            value: 100e18,
            nonce: 0,
            deadline: block.timestamp + 1 days
        });

        bytes32 digest = sigUtils.getTypedDataHash(permit);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(sigPk, digest);

        vm.mockCall(address(iToken0), abi.encodeWithSignature("symbol()"), abi.encode("frxUSD"));

        vm.startPrank(freshUser);
        iBammErc20.permit(sigTester, freshUser, 100e18, block.timestamp + 1 days, v, r, s);

        console.log(iBammErc20.allowance(sigTester, freshUser));
    }

    function test_sig_notReplayableAccrossBamms() public {
        _initSigBammToken();
        sigUtils = new SigUtils(ERC20Permit(address(iBammErc20)).DOMAIN_SEPARATOR());
        deal(address(iBammErc20), sigTester, 100e18);

        SigUtils.Permit memory permit = SigUtils.Permit({
            owner: sigTester,
            spender: freshUser,
            value: 100e18,
            nonce: 0,
            deadline: block.timestamp + 1 days
        });

        bytes32 digest = sigUtils.getTypedDataHash(permit);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(sigPk, digest);

        _createFreshBamm();

        console.log("owner: ", sigTester, "spender: ", freshUser);
        vm.startPrank(freshUser);

        console.log(address(iBammErc20));
        vm.expectRevert();
        iBammErc20.permit(sigTester, freshUser, 100e18, block.timestamp + 1 days, v, r, s);
    }

    function _initSigBammToken() public {
        sigUtils = new SigUtils(ERC20Permit(address(iBammErc20)).DOMAIN_SEPARATOR());
        sigPk = 0xFFFFF115;
        sigTester = vm.addr(sigPk);
    }
}
