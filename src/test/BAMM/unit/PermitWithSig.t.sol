// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import "../../helpers/BAMMTestHelper.sol";

contract BammPermitTest is BAMMTestHelper {
    function setUp() public {
        defaultSetup();
        _createFreshBamm();
        _initSigs();
    }

    function test_deposit_token0_with_signature() public {
        sigUtils = new SigUtils(ERC20Permit(address(iToken0)).DOMAIN_SEPARATOR());
        deal(address(iToken0), sigTester, 100e18);

        SigUtils.Permit memory permit = SigUtils.Permit({
            owner: sigTester,
            spender: bamm,
            value: 100e18,
            nonce: 0,
            deadline: block.timestamp + 1 days
        });

        bytes32 digest = sigUtils.getTypedDataHash(permit);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(sigPk, digest);

        IBAMM.Action memory action;
        action.token0Amount = 100e18;
        action.v = v;
        action.r = r;
        action.s = s;
        action.deadline = block.timestamp + 1 days;

        vm.prank(sigTester);
        iBamm.executeActions(action);

        (int256 token0Amount, , ) = iBamm.userVaults(sigTester);

        assertEq({ a: action.token0Amount, b: token0Amount, err: "// THEN: Vault balance not incremented correctly" });
        assertEq({
            a: iToken0.balanceOf(bamm),
            b: uint256(token0Amount),
            err: "// THEN: Tokens were not transfered to bamm"
        });
        assertEq({ a: iToken0.allowance(sigTester, bamm), b: 0, err: "// THEN: Allowance was not decremented" });
    }

    function test_deposit_token0_approveMax_with_signature() public {
        sigUtils = new SigUtils(ERC20Permit(address(iToken0)).DOMAIN_SEPARATOR());
        deal(address(iToken0), sigTester, 100e18);

        SigUtils.Permit memory permit = SigUtils.Permit({
            owner: sigTester,
            spender: bamm,
            value: type(uint256).max,
            nonce: 0,
            deadline: block.timestamp + 1 days
        });

        bytes32 digest = sigUtils.getTypedDataHash(permit);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(sigPk, digest);

        IBAMM.Action memory action;
        action.token0Amount = 100e18;
        action.v = v;
        action.r = r;
        action.s = s;
        action.approveMax = true;
        action.deadline = block.timestamp + 1 days;

        vm.prank(sigTester);
        iBamm.executeActions(action);

        (int256 token0Amount, , ) = iBamm.userVaults(sigTester);

        assertEq({ a: action.token0Amount, b: token0Amount, err: "// THEN: Vault balance not incremented correctly" });
        assertEq({
            a: iToken0.balanceOf(bamm),
            b: uint256(token0Amount),
            err: "// THEN: Tokens were not transfered to bamm"
        });
        assertEq({
            a: iToken0.allowance(sigTester, bamm),
            b: type(uint256).max,
            err: "// THEN: Allowance not expected"
        });
    }

    function test_deposit_token1_with_signature() public {
        sigUtils = new SigUtils(ERC20Permit(address(iToken1)).DOMAIN_SEPARATOR());
        deal(address(iToken1), sigTester, 100e18);

        SigUtils.Permit memory permit = SigUtils.Permit({
            owner: sigTester,
            spender: bamm,
            value: 100e18,
            nonce: 0,
            deadline: block.timestamp + 1 days
        });

        bytes32 digest = sigUtils.getTypedDataHash(permit);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(sigPk, digest);

        IBAMM.Action memory action;
        action.token1Amount = 100e18;
        action.v = v;
        action.r = r;
        action.s = s;
        action.deadline = block.timestamp + 1 days;

        vm.prank(sigTester);
        iBamm.executeActions(action);

        (, int256 token1Amount, ) = iBamm.userVaults(sigTester);

        assertEq({
            a: iToken1.balanceOf(bamm),
            b: uint256(token1Amount),
            err: "// THEN: Tokens were not transfered to bamm"
        });
        assertEq({ a: action.token1Amount, b: token1Amount, err: "// THEN: Vault balance not incremented correctly" });
        assertEq({ a: iToken1.allowance(sigTester, bamm), b: 0, err: "// THEN: Allowance was not decremented" });
    }

    function test_deposit_token1_with_approveMax_signature() public {
        sigUtils = new SigUtils(ERC20Permit(address(iToken1)).DOMAIN_SEPARATOR());
        deal(address(iToken1), sigTester, 100e18);

        SigUtils.Permit memory permit = SigUtils.Permit({
            owner: sigTester,
            spender: bamm,
            value: type(uint256).max,
            nonce: 0,
            deadline: block.timestamp + 1 days
        });

        bytes32 digest = sigUtils.getTypedDataHash(permit);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(sigPk, digest);

        IBAMM.Action memory action;
        action.token1Amount = 100e18;
        action.v = v;
        action.r = r;
        action.s = s;
        action.approveMax = true;
        action.deadline = block.timestamp + 1 days;

        vm.prank(sigTester);
        iBamm.executeActions(action);

        (, int256 token1Amount, ) = iBamm.userVaults(sigTester);
        assertEq({ a: action.token1Amount, b: token1Amount, err: "// THEN: Vault balance not incremented correctly" });
        assertEq({
            a: iToken1.balanceOf(bamm),
            b: uint256(token1Amount),
            err: "// THEN: Tokens were not transfered to bamm"
        });
        assertEq({
            a: iToken1.allowance(sigTester, bamm),
            b: type(uint256).max,
            err: "// THEN: Allowance not expected"
        });
    }

    function test_deposit_invalid_signature() public {
        sigUtils = new SigUtils(ERC20Permit(address(iToken1)).DOMAIN_SEPARATOR());
        deal(address(iToken0), sigTester, 100e18);

        SigUtils.Permit memory permit = SigUtils.Permit({
            owner: sigTester,
            spender: bamm,
            value: 100e18,
            nonce: 0,
            deadline: block.timestamp + 1 days
        });

        bytes32 digest = sigUtils.getTypedDataHash(permit);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(sigPk, digest);

        IBAMM.Action memory action;
        action.token0Amount = 100e18;
        action.v = v;
        action.r = r;
        action.s = s;
        action.deadline = block.timestamp + 1 days;

        vm.expectRevert();
        vm.prank(sigTester);
        iBamm.executeActions(action);
    }

    function test_repay_with_signature() public {
        _seedFreshPair();
        _bamm_mint({ _bamm: bamm, _user: tester, _to: tester, _pair: pair, _amountPair: iPair.balanceOf(tester) });
        _bamm_deposit({
            _bamm: bamm,
            _token0: token0,
            _token1: token1,
            _user: sigTester,
            _token0Amount: 10e18,
            _token1Amount: 10e18
        });

        _bamm_rent({ _bamm: bamm, _user: sigTester, _rent: int256(90e18) });

        vm.warp(block.timestamp + 60 days);
        iBamm.addInterest();

        sigUtils = new SigUtils(ERC20Permit(address(iToken0)).DOMAIN_SEPARATOR());
        SigUtils.Permit memory permit = SigUtils.Permit({
            owner: sigTester,
            spender: bamm,
            value: type(uint256).max,
            nonce: 0,
            deadline: block.timestamp + 70 days
        });

        bytes32 digest = sigUtils.getTypedDataHash(permit);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(sigPk, digest);

        IBAMM.Action memory action;
        action.closePosition = true;
        action.v = v;
        action.r = r;
        action.s = s;
        action.approveMax = true;
        action.deadline = block.timestamp + 70 days;

        deal(address(iToken0), sigTester, 1000e18);
        deal(address(iToken1), sigTester, 1000e18);

        vm.startPrank(sigTester);
        iToken1.approve(bamm, type(uint256).max);
        iBamm.executeActions(action);

        (, , int256 rent) = iBamm.userVaults(sigTester);
        assertEq({ a: rent, b: 0, err: "// THEN: Position not closed" });
        assertEq({
            a: iToken1.allowance(sigTester, bamm),
            b: type(uint256).max,
            err: "// THEN: Allowance not expected"
        });
        assertEq({
            a: iToken0.allowance(sigTester, bamm),
            b: type(uint256).max,
            err: "// THEN: Allowance not expected"
        });
    }

    function _seedFreshPair() public {
        deal(address(iToken0), tester, 100e18);
        deal(address(iToken1), tester, 100e18);
        vm.startPrank(tester);
        iToken0.transfer(pair, 100e18);
        iToken1.transfer(pair, 100e18);
        iPair.mint(address(tester));
        vm.stopPrank();
    }
}
