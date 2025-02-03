methods
{
    function FraxswapPair.price0CumulativeLast() external returns (uint256) => NONDET ALL;
    function FraxswapPair.price1CumulativeLast() external returns (uint256) => NONDET ALL; 
    function FraxswapPair.getTWAPHistoryLength() external returns (uint256) => NONDET ALL;
    function FraxswapPair.getOrderIDsForUser(address user) external returns (uint256[]) => NONDET ALL;
    function FraxswapPair.getOrderIDsForUserLength(address user) external returns (uint256) => NONDET ALL;
    function FraxswapPair.getDetailedOrdersForUser(address user, uint256 offset, uint256 limit) external returns (LongTermOrdersLib.Order[]) => NONDET ALL;
    function FraxswapPair.getReserves() external returns (uint112, uint112, uint32) envfree;
    function FraxswapPair.getTwammReserves() external returns (uint112, uint112, uint32, uint112, uint112, uint256) =>  NONDET ALL;
    function FraxswapPair.getAmountOut(uint256 amountIn, address tokenIn) external returns (uint256) => NONDET ALL;
    function FraxswapPair.getAmountIn(uint256 amountOut, address tokenOut) external returns (uint256) => NONDET ALL;
    function FraxswapPair.mint(address to) external returns (uint256);
    function FraxswapPair.burn(address to) external returns (uint256, uint256);
    function FraxswapPair.swap(uint256, uint256,address,bytes) external => NONDET ALL;
    function FraxswapPair.skim(address to) external => NONDET ALL;
    function FraxswapPair.sync() external => NONDET ALL;
	function FraxswapPair.totalSupply() external returns (uint256) envfree;
    function FraxswapPair.balanceOf(address) external returns (uint256) envfree;

	// summarising to avoid "call(...)"
    function _.safeTransfer(address token, address to, uint256 value) internal
        => cvlTransfer(token, to, value) expect (bool, bytes memory);

    function _.safeTransferFrom(address token, address from, address to, uint256 value) internal
        => cvlTransferFrom(token, from, to, value) expect (bool, bytes memory);
}

function cvlTransfer(address token, address to, uint256 value) returns (bool, bytes) {
    env e;
    require e.msg.sender == currentContract;
    require e.msg.value == 0;
    token.transfer(e, to, value);
    bool success;
    bytes resBytes;
    return (success, resBytes);
}

function cvlTransferFrom(address token, address from, address to, uint256 value) returns (bool, bytes) {
    env e;
    require e.msg.sender == currentContract;
    require e.msg.value == 0;
    token.transferFrom(e, from, to, value);
    bool success;
    bytes resBytes;
    return (success, resBytes);
}
