// SPDX-License-Identifier: ISC
pragma solidity ^0.8.19;

import "frax-std/FraxTest.sol";
import "../../BaseTest.t.sol";
import "../../../Constants.sol";

contract BAMMFeeTest is BaseTest {
    IERC20 FRAX = IERC20(0x853d955aCEf822Db058eb8505911ED77F175b99e);
    IERC20 FXS = IERC20(0x3432B6A60D23Ca0dFCa7761B7ab56459D9C964D0);
    address FRAXFXSPool = 0x03B59Bd1c8B9F6C265bA0c3421923B93f15036Fa;

    function setUpEthereum() public {
        vm.createSelectFork(vm.envString("MAINNET_RPC_URL"), 18_850_000);
        iRouterMultihop = IFraxswapRouterMultihop(payable(0x25e9acA5951262241290841b6f863d59D37DC4f0));

        _initializeAccounts();

        // Deploy the contracts
        // ======================
        (, oracle) = deployFraxswapOracle();
        (iBammHelper, bammHelper) = deployBammHelper();
        (iVariableInterestRate, variableInterestRate) = deployVariableInterestRate();
        (iBammFactory, bammFactory) = deployBammFactory({
            _fraxswapFactory: pairFactory,
            _routerMultihop: routerMultihop,
            _fraxswapOracle: oracle,
            _variableInterestRate: variableInterestRate,
            _feeTo: address(0)
        });

        // create the BAMM and BAMMERC20
        (iVariableInterestRate, variableInterestRate) = deployVariableInterestRate();
        bamm = iBammFactory.createBamm(FRAXFXSPool);
        iBamm = BAMM(bamm);
        iBammErc20 = iBamm.iBammErc20();
        bammErc20 = address(iBammErc20);

        // Set up Alice
        alicePrivateKey = 0xA11CE2;
        alice = payable(vm.addr(alicePrivateKey));
        vm.label(alice, "Alice");

        // Set up Bob
        bobPrivateKey = 0xB0B2;
        bob = payable(vm.addr(bobPrivateKey));
        vm.label(bob, "Bob");
    }

    function test_fee() public {
        setUpEthereum();
        iBammFactory.setFeeTo(alice);
        address feeReceiver = iBammFactory.feeTo();
        uint256 balanceBefore = iBammErc20.balanceOf(feeReceiver);
        // Lend Lp tokens
        hoax(Mainnet.AMO_OWNER);
        IERC20(FRAXFXSPool).approve(address(bamm), 100e18);
        hoax(Mainnet.AMO_OWNER);
        BAMM(bamm).mint(address(Mainnet.AMO_OWNER), 100e18);

        // Deposit/rent
        hoax(Mainnet.AMO_OWNER);
        IERC20(FRAX).approve(bamm, 100e18);
        IBAMM.Action memory action = IBAMM.Action(
            0,
            13.865e18,
            int256((90e18 * 1e18) / iBamm.rentedMultiplier()),
            address(Mainnet.AMO_OWNER),
            0,
            0,
            false,
            false,
            0,
            0,
            0,
            0
        );
        hoax(Mainnet.AMO_OWNER);
        BAMM(bamm).executeActions(action);

        mineBlocksBySecond(10 days);
        BAMM(bamm).addInterest();
        uint256 balanceAfter = iBammErc20.balanceOf(feeReceiver);
        console.logAddress(feeReceiver);
        console.log("fees earned:", (balanceAfter - balanceBefore));
    }
}
