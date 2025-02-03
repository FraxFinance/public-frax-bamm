//import "unresolved_common.spec";

// summaries for unresolved calls
methods {
    // BAMMERC20 // no longer needed. the bammerc20 is linked
    //function _.burn(address account, uint256 value) external => DISPATCHER(true);
    //function _.mint(address,uint256) external => DISPATCHER(true);


    // causes memory partition failures
    // EIP712 
    function _.eip712Domain() external => NONDET DELETE;

    // causes memory partition failures
    // BAMMFactory  
    function _.createBamm(address) external => NONDET DELETE;

    // VariableInterestRate
    function VariableInterestRate.getNewRate(uint256,uint256,uint64) external returns (uint64, uint64) => NONDET DELETE;
    // function VariableInterestRate.getNewRate(uint256,uint256,uint64) external returns (uint64, uint64) => getNewRateMy();

}


// ghost uint256 getNewRateCVL {
//     axiom getNewRateCVL >= 31649409;
// }

function getNewRateMy() returns (uint64, uint64) {
        uint64  _newRatePerSec;
        uint64  _newFullUtilizationInterest;
        require _newRatePerSec >= 31649409;
        require _newFullUtilizationInterest >= 31649409;
        return (_newRatePerSec,_newFullUtilizationInterest);
}