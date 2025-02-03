// SPDX-License-Identifier: ISC
pragma solidity ^0.8.19;

import "frax-std/FraxTest.sol";
import "../../BaseTest.t.sol";
import "../../helpers/BAMMTestHelper.sol";
import { BAMMUIHelper } from "../../../contracts/BAMMUIHelper.sol";
import "../../../Constants.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";

contract BAMMUIHelperTestcase is BaseTest, BAMMTestHelper {
    function setUp() public {
        vm.createSelectFork(vm.envString("FRAXTAL_MAINNET_URL"), 5_344_774);
        iBammUIHelper = BAMMUIHelper(0x179Bfd453324a94a91E85671C817d04aF635a120);
        bamm = 0x181914A3E52eCa9998f22ac71D942DBA04CAf466;
        iBamm = BAMM(bamm);
    }

    function test_testcase() public {
        address user = 0xC6EF452b0de9E95Ccb153c2A5A7a90154aab3419;
        BAMMUIHelper.BAMMState memory state = iBammUIHelper.getBAMMState(iBamm);
        console.log("state");
        console.log(state.reserve0);
        console.log(state.reserve1);
        console.log(state.totalSupply);
        console.log(state.rentedMultiplier);
        console.log(state.sqrtBalance);
        console.log(state.sqrtRentedReal);
        console.log(state.utilityRate);
        console.log(state.ratePerSec);
        console.log(state.bammTokenTotalSupply);
        console.log(state.sqrtPerBAMMToken);
        console.log(state.sqrtPerLPToken);
        console.log(state.token0PerSqrt);
        console.log(state.token1PerSqrt);

        console.log("vault");
        BAMMUIHelper.BAMMVault memory vault = iBammUIHelper.getVaultState(iBamm, user);
        console.logInt(vault.token0);
        console.logInt(vault.token1);
        console.logInt(vault.rented);
        console.log(vault.rentedReal);
        console.logInt(vault.rentedToken0);
        console.logInt(vault.rentedToken1);
        console.log(vault.ltv);
        console.logInt(vault.value0);
        console.logInt(vault.value1);
        console.logInt(vault.leverage0);
        console.logInt(vault.leverage1);
        console.logBool(vault.solvent);
        console.logBool(vault.solventAfterAction);

        int256 toBorrow1 = 3.78899e16;
        int256 newNetToken0 = vault.token0 - vault.rentedToken0;
        int256 newNetToken1 = vault.token1 - vault.rentedToken1 - toBorrow1;
        int256 toRent = iBammUIHelper.calcRentForLTV(iBamm, newNetToken0, newNetToken1, 0, 0.9749e18);
        console.log("toRent");
        console.log(toRent);
        toRent = iBammUIHelper.calcRentForLTV(iBamm, newNetToken0, newNetToken1, vault.rented, 0.9749e18);
        console.log("toRent");
        console.log(toRent);
        /*BAMM.Action memory action = IBAMM.Action(0,-toBorrow1,toRent,user,0,0,false,false,0,0,0,0);       
       vm.prank(user);
       BAMM(bamm).executeActions(action);
       
       vault = iBammUIHelper.getVaultState(iBamm,user);
       console.log("vault");
       console.logInt(vault.token0); 
       console.logInt(vault.token1);
       console.logInt(vault.rented);
       console.log(vault.rentedReal);
       console.logInt(vault.rentedToken0);
       console.logInt(vault.rentedToken1);
       console.log(vault.ltv);
       console.logInt(vault.value0);
       console.logInt(vault.value1);
       console.logInt(vault.leverage0);
       console.logInt(vault.leverage1);
       console.logBool(vault.solvent);
       console.logBool(vault.solventAfterAction);*/
    }

    struct BAMMVault {
        int256 token0;
        int256 token1;
        int256 rented;
        uint256 rentedReal;
        int256 rentedToken0;
        int256 rentedToken1;
        uint256 ltv;
        int256 value0;
        int256 value1;
        int256 leverage0;
        int256 leverage1;
        bool solvent;
        bool solventAfterAction;
    }
}
