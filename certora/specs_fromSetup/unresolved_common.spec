methods {
    // IFraxswapPair
    function _.fee() external => DISPATCHER(true);
    function _.sync() external => DISPATCHER(true);
    function _.kLast() external => DISPATCHER(true);
    function _.totalSupply() external => DISPATCHER(true);
    function _.balanceOf(address) external => DISPATCHER(true);
    function _.getReserves() external => DISPATCHER(true);
    function _.swap(uint256,uint256,address,bytes) external => DISPATCHER(true);
    function _.burn(address) external => DISPATCHER(true);
    function _.mint(address) external => DISPATCHER(true);
    function _.getReserveAfterTwamm(uint256) external => DISPATCHER(true);
    function _.getTWAPHistoryLength() external => DISPATCHER(true);
    function _.TWAPObservationHistory(uint256) external => DISPATCHER(true);
    function _.executeVirtualOrders(uint256) external => DISPATCHER(true);
    function _.token0() external => DISPATCHER(true);
    function _.token1() external => DISPATCHER(true);
   
    // BAMMFactory
    function _.feeTo() external => DISPATCHER(true);

    // VariableInterestRate
    // function _.getNewRate(uint256, uint256, uint64) external => DISPATCHER(true);
}