using DummyERC20A as _token0;
using DummyERC20B as _token1;
using DummyERC20C as pairERC20;
using FraxswapPair as pair;

methods
{

function _._calcMintedSupplyFromPairMintFee(uint112 _reserve0, uint112 _reserve1, uint256 totalSupply) internal  => calMintedSupply(reserve0, reserve1, totalSupply, kLast) expect (uint256);
function _token0.balanceOf(address) external returns (uint256) envfree;
function _token1.balanceOf(address) external returns (uint256) envfree;
function pairERC20.balanceOf(address) external returns (uint256) envfree;
function pairERC20.totalSupply() external returns (uint256) envfree;
function pairERC20._mint(address, uint256) external envfree;
function pairERC20._burn(address, uint256) external envfree;


/*--------------------- FraxSwapPair methods -----------------------*/

function FraxswapPair.token0() external returns (address)=> _token0;
function FraxswapPair.token1() external returns (address)=> _token1;
function FraxswapPair.balanceOf(address user) external returns (uint256) envfree => CvlBalanceOf(user);
function FraxswapPair.burn(address to) external returns (uint256, uint256) => CvlBurn(calledContract, to);
function FraxswapPair.mint(address to) external returns (uint256) => CvlMint(to);
function FraxswapPair.getReserves() external returns (uint112, uint112, uint32) => CvlReserves();
function FraxswapPair.totalSupply() external returns (uint256) envfree => CvlTotalSupply();

function FraxswapPair.price0CumulativeLast() external returns (uint256) => NONDET ALL;
function FraxswapPair.price1CumulativeLast() external returns (uint256) => NONDET ALL; 
function FraxswapPair.getTWAPHistoryLength() external returns (uint256) => NONDET ALL;
function FraxswapPair.getOrderIDsForUser(address user) external returns (uint256[]) => NONDET ALL;
function FraxswapPair.getOrderIDsForUserLength(address user) external returns (uint256) => NONDET ALL;
function FraxswapPair.getDetailedOrdersForUser(address user, uint256 offset, uint256 limit) external returns (LongTermOrdersLib.Order[]) => NONDET ALL;
function FraxswapPair.getTwammReserves() external returns (uint112, uint112, uint32, uint112, uint112, uint256) =>  NONDET ALL;
function FraxswapPair.getAmountOut(uint256 amountIn, address tokenIn) external returns (uint256) => NONDET ALL;
function FraxswapPair.getAmountIn(uint256 amountOut, address tokenOut) external returns (uint256) => NONDET ALL;
function FraxswapPair.swap(uint256, uint256,address,bytes) external => NONDET ALL;
function FraxswapPair.skim(address to) external => NONDET ALL;
function FraxswapPair.sync() external => NONDET ALL;
function FraxswapPair.kLast() external returns (uint256) envfree => kLast;

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
    if (token == pair){
        pairERC20.transfer(e, to, value);
    } else{
        token.transfer(e, to, value);
    }
    bool success;
    bytes resBytes;
    return (success, resBytes);
}

function cvlTransferFrom(address token, address from, address to, uint256 value) returns (bool, bytes) {
    env e;
    require e.msg.sender == currentContract;
    require e.msg.value == 0;
    if (token == pair){
        pairERC20.transferFrom(e, from, to, value);
    } else{
        token.transferFrom(e, from, to, value);
    }
    bool success;
    bytes resBytes;
    return (success, resBytes);
}


persistent ghost uint112 reserve0;
persistent ghost uint112 twammReserve0;
persistent ghost uint112 reserve1;
persistent ghost uint112 twammReserve1;

persistent ghost uint256 LPtotalSupply;
persistent ghost uint256 kLast;//calcmint should take this as a parameter

ghost uint32 blockTimestampLast;

function CvlReserves() returns (uint112, uint112, uint32){
    return (reserve0, reserve1, blockTimestampLast);
}

function CvlBalanceOf(address user) returns uint256 {
    return pairERC20.balanceOf(user);
}

function CvlTotalSupply() returns uint256 {
    return pairERC20.totalSupply();
}
persistent ghost _calcMintedSupplyFromPairMintFee(uint112, uint112, uint256) returns uint256;

// checks LP balance of pair contract
function CvlBurn(address from, address to) returns (uint256, uint256){
    uint256 balance0 = require_uint256(_token0.balanceOf(pair) - twammReserve0);
    uint256 balance1 = require_uint256(_token1.balanceOf(pair) - twammReserve1);

    uint256 liquidity = pairERC20.balanceOf(pair);

    uint256 TSFeeDelta = calMintedSupply(reserve0, reserve1, pairERC20.totalSupply(), kLast);

    address feeTo;
    pairERC20._mint(feeTo, TSFeeDelta);

    uint256 totalSupply = pairERC20.totalSupply();
 
    // calculate the constituent tokesn for the supplied LP tokens
    uint256 amount0 = require_uint256((liquidity * balance0) / totalSupply); // using balances ensures pro-rata distribution
    uint256 amount1 = require_uint256((liquidity * balance1) / totalSupply); // using balances ensures pro-rata distribution

    // burn LP tokens
    
    pairERC20._burn(pair, liquidity);

    cvlTransferFrom(_token0, from, to, amount0);
    cvlTransferFrom(_token1, from, to, amount1);

    reserve0 = require_uint112(_token0.balanceOf(pair) - twammReserve0);
    reserve1 = require_uint112(_token1.balanceOf(pair) - twammReserve1);

    havoc kLast;
    // kLast = _; //or assign an uninitialized variable
    return (amount0, amount1);
}

function CvlMint(address to) returns uint256{
    uint256 balance0 = require_uint256(_token0.balanceOf(pair) - twammReserve0);
    uint256 balance1 = require_uint256(_token1.balanceOf(pair) - twammReserve1);

    uint256 amount0 = require_uint256(balance0 - reserve0);
    uint256 amount1 = require_uint256(balance1 - reserve0);

    uint256 TSFeeDelta = calMintedSupply(reserve0, reserve1, pairERC20.totalSupply(), kLast);
    address feeTo;
    pairERC20._mint(feeTo, TSFeeDelta);

    uint256 totalSupply = pairERC20.totalSupply();

    uint256 liquidity = (amount0 * totalSupply) / reserve0 < (amount1 * totalSupply) / reserve1? require_uint256((amount0 * totalSupply) / reserve0) : require_uint256((amount1 * totalSupply) / reserve1);
    
    pairERC20._mint(to, liquidity);

    reserve0 = require_uint112(balance0);
    reserve1 = require_uint112(balance1);

    havoc kLast;
    // kLast = _; //or assign an uninitialized variable
    return liquidity;
}

ghost calMintedSupply(uint112, uint112, uint256, uint256) returns uint256;

