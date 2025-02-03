import "unresolved_common.spec";

// summaries for unresolved calls
methods {
    // BAMM
    function _.version() external => DISPATCHER(true);
    function _.pair() external => DISPATCHER(true);
    function _.mint(address to, uint256 lpIn) external => DISPATCHER(true);
    function _.redeem(address to, uint256 bammIn) external => DISPATCHER(true);
    function _.executeActions(IBAMM.Action action) external => DISPATCHER(true);
    function _.executeActionsAndSwap(
        IBAMM.Action action,
        IFraxswapRouterMultihop.FraxswapParams swapParams
    ) external => DISPATCHER(true);
    function _.microLiquidate(address user) external => DISPATCHER(true);
    function _.addInterest() external => DISPATCHER(true);
    function _.solvent(address user) external => DISPATCHER(true);
    function _.previewInterestRate(uint256 _utilization) external => DISPATCHER(true);
    function _.ltv(address user) external => DISPATCHER(true);
    function _.ltv(IBAMM.Vault vault) external => DISPATCHER(true);
    function _.currentUtilityRate() external => DISPATCHER(true);
    function _.fullUtilizationRate() external => DISPATCHER(true);
    function _.variableInterestRate() external => DISPATCHER(true);
    function _.SOLVENCY_THRESHOLD_LIQUIDATION() external => DISPATCHER(true);
    function _.SOLVENCY_THRESHOLD_AFTER_ACTION() external => DISPATCHER(true);
    function _.userVaults(address) external => DISPATCHER(true);
    function _.sqrtRented() external => DISPATCHER(true);
    function _.timeSinceLastInterestPayment() external => DISPATCHER(true);
    function _.iBammErc20() external => DISPATCHER(true);
}