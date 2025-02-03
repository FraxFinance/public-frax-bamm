import "MathSummaries.spec";

// these are hard methods, out of scope of the project
methods
{
    function FraxswapPair.mint(address to) external returns (uint256) => NONDET ALL;
    function FraxswapPair.burn(address to) external returns (uint256, uint256) => NONDET ALL;
    //function FraxswapPair.mint(address to) external returns (uint256) => CvlMint(to);
    //function FraxswapPair.burn(address to) external returns (uint256, uint256) => CvlBurn(to);

    function FraxswapPair.price0CumulativeLast() external returns (uint256) => NONDET ALL;
    function FraxswapPair.price1CumulativeLast() external returns (uint256) => NONDET ALL; 
    function FraxswapPair.getTWAPHistoryLength() external returns (uint256) => NONDET ALL;
    function FraxswapPair.getOrderIDsForUser(address user) external returns (uint256[]) => NONDET ALL;
    function FraxswapPair.getOrderIDsForUserLength(address user) external returns (uint256) => NONDET ALL;
    //function FraxswapPair.getDetailedOrdersForUser(address user, uint256 offset, uint256 limit) external returns (LongTermOrdersLib.Order[]) => NONDET ALL;
    //function FraxswapPair.getReserves() external returns (uint112, uint112, uint32) => NONDET ALL;
    function FraxswapPair.getTwammReserves() external returns (uint112, uint112, uint32, uint112, uint112, uint256) =>  NONDET ALL;
    function FraxswapPair.getAmountOut(uint256 amountIn, address tokenIn) external returns (uint256) => NONDET ALL;
    function FraxswapPair.getAmountIn(uint256 amountOut, address tokenOut) external returns (uint256) => NONDET ALL;

    //function FraxswapPair.swap(uint256 amount0Out, uint256 amount1Out, address to, bytes data) external => NONDET ALL;
    //function FraxswapPair.swap(uint256 amount0Out, uint256 amount1Out, address to, bytes data) external 
    //    => simpleSwap(amount0Out, amount1Out, calledContract, to, data);
    function FraxswapPair.skim(address to) external => NONDET ALL;
    function FraxswapPair.sync() external => NONDET ALL;

    // IUniswapV2Callee
    //function _.uniswapV2Call(address,uint256,uint256,bytes) external => NONDET ALL;

    // summarising to avoid "call(...)"
    function _.safeTransfer(address token, address to, uint256 value) internal
        => cvlTransfer(token, to, value) expect (bool, bytes memory);

    function _.safeTransferFrom(address token, address from, address to, uint256 value) internal
        => cvlTransferFrom(token, from, to, value) expect (bool, bytes memory);

    function _.safeIncreaseAllowance(address token, address spender, uint256 value) internal
        => NONDET;

    // VariableInterestRate
    function _.getNewRate(uint256, uint256, uint64) external => NONDET DELETE;

    // ERC20 permit
    function _.permit(address,address,uint256,uint256,uint8,bytes32,bytes32) external => NONDET ALL;
    // ERC20 permit - Alex:
    // function _.permit(address,address,uint256,uint256,uint8,bytes32,bytes32) external => DISPATCHER(true);
    // function _.approve(address,uint256) external => NONDET;



    // FraxSwapOracle
    function _.getPrice(address,uint256,uint256,uint256) external => NONDET DELETE;

    //this just reverts if the oracle price differs too much. No need to worry about it
	function _.ammPriceCheck(uint112, uint112) internal => NONDET ALL; 

    function _.getMaxSell(uint256, uint256, uint256, uint256) internal => NONDET ALL;
    //function _.getMaxSell(uint256 tokenIn,uint256 tokenOut,uint256 reserveIn,uint256 reserveOut) external
    //    => simpleGetMaxSell(tokenIn, tokenOut, reserveIn, reserveOut) expect uint256;
}

function simpleGetMaxSell(uint256 tokenIn,uint256 tokenOut,
    uint256 reserveIn, uint256 reserveOut) returns uint256
{
    mathint x; mathint y;
    require x > 0 && y > 0 && x < tokenIn;
    require reserveIn > 0;
    //require maxDifference((reserveOut - y) / (reserveIn + x),
    //   (tokenOut+y)/(tokenIn-x), 1);   //differs by at most one

    require (reserveOut-y)/(reserveIn+x) == (tokenOut+y)/(tokenIn-x);
    require (reserveOut-y)*(reserveIn+x) == reserveIn*reserveOut;
    return require_uint256(x);
}

function simpleSwap(uint256 token0, uint256 token1, address from, address to, bytes b)
{
    if (token0 > 0) cvlTransferFrom(get_token0(), from, to, token0); 
    if (token1 > 0) cvlTransferFrom(get_token1(), from, to, token1);
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