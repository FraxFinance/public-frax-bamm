# Frax Finance: BAMM
[![Node.js CI](https://github.com/FraxFinance/public-frax-bamm/actions/workflows/main.yml/badge.svg)](https://github.com/FraxFinance/public-frax-bamm/actions/workflows/main.yml)

### Introduction

The BAMM is a borrowing/lending AMM with underlying `K = x*y` universal AMM, hence "BAMM." Users can swap spot between two tokens or use one token as collateral to borrow part of the reserves of the other token. Thus, the BAMM allows for permissionlessly creating liquidity pools that double as lending markets, a 0 to 1 innovation in DeFi that allows any token to have spot liquidity and a lending market in a single venue. 

Unlike other borrowing lending protocols, the BAMM does not need an outside oracle or external liquidity to function safely. Because the BAMM denominates debt priced in `K = x*y`, there is no risk of "bad debt" like classical lending protocols because the liquidity needed to liquidate borrowers is mathematically always present in the underlying AMM. 

Any user can create any BAMM pair between two tokens just like Uniswap or other universal `K = x*y` AMMs. However, the novel innovation is that, the token reserves double as both a swap venue as well as a lending market in a seamless manner. BAMM LPs earn both the interest rate paid by borrowers as well as swap fees making the BAMM always more profitable to LP into than Uniswap v2 style protocols.


## Prelude 

Constant product AMM's define `K = x*y` Where `x` and `y` are the reserves of tokenA and tokenB in the pair. Similarly the LP token of the AMM is a shares based math representation of your ownership in `sqrt(K)`.


The BAMM builds upon this concept by allowing LP holders to tokenize and effectively lend out the percent of ownership of `sqrt(K)` their LP tokens confer via minting BAMM-ERC20 tokens. Similarly, users are able issue debt denominated in `sqrt(K)` via renting and unwinding LP tokens in their vaults.



## BAMM Innovation: Profit from Volatility
Since Debt is denominated loosely in terms of sqrt(K) it becomes possible to profit from [impermanent loss](https://academy.binance.com/en/articles/impermanent-loss-explained) of a liquidity pair through renting the underlying LP token. 

How exactly can you profit against price volatility, aka. impermanent loss?  When a user rents, they are burning the LP token to hold the underlying `token0` and `token1` within their vault, and the sqrt(K) (their denominated loan) is based on the token price at that time.  When price changes, the renter has a profit value equal to the impermanent loss they've removed from the pool through renting.  As impermanent loss happens bi-directionally (ie. when `token0` is either worth *more* or *less* than `token1`), profit function is bi-directional.

The following should serve as a simplified example of how a unit of rent's value (denominated in USD) can vary dependent on the price of the token in the AMM.
```
- Price Initial 1 eth: 100 FRAX 
- TS pair is 100 LP Tokens, ReserveA: 10 && ReserveB: 1000
- sqrt(A*B) == 100
- rentedMultiplier == 1e18

1 Unit Rented -> 1 unit rented Real 
-> 1e18*100e18 [LP_TS] / sqrt(1000e18*10e18)
-> 1 LP token rented -> 0.1 ETH & 10 FRAX ~ 20$ USD 


- Price Final 1 eth: 25 FRAX 
- TS pair is 100 LP Tokens, ReserveA: 20 && ReserveB: 500
- sqrt(A*B) == 100
- rentedMultiplier == 1e18

1 Unit Rented -> 1 unit rented Real 
-> 1e18*100e18 [LP_TS] / sqrt(500e18*20e18)
-> 1 LP token rented -> 0.2 ETH & 5 FRAX ~ 10$ USD 

```

In reality as the `block.timestamp` increases the `rentedMultiplier` will increase in value, resulting in an increase in the amount of LP corresponding to a single unit rented, holding `LP Total Supply` and the `K` constant.

<br></br>

## BAMM-ERC20

The BAMM-ERC20 token is a shares based math token based on the square root of the AMM's constant product. It can be thought of your share in the square root of the underlying pairs reserves (`token0`, `token1`).  

Assuming users have approved the bamm to spend the underlying LP token, users are able to mint bamm proportional to the amount of LP provided. 

If the user mints BAMM tokens when the `totalSupply()` of the BAMM-ERC20 token is 0, they will receive a quantity of bamm tokens which is proportional to the percent ownership of the squareRoot of the reserves in the underlying pair, less `1e3` (which is the minimum liquidity locked by the bamm). 

All other users who deposit in the bamm will likewise receive BAMM-ERC20 tokens proportional to their LP tokens, which represent the percent ownership of the square root of the reserves in the underlying pair, less interest previously accrued to BAMM-ERC20 Holders.

## BAMM-ERC20 Value Accrual


Holding BAMM-ERC20 tokens can be thought of as holding exposure to the square root of the underlying AMMs reserves, which will be monotonically increasing due to the growth in `rentedMultiplier()`, assuming there is no bad debt.

It is important to note that the APR in the BAMM is not strictly additive with the underlying LP's swap fee APR. For example, if an underlying LP has an APR of 3% and the bamm has an APR of 8% on rented LP with an utilization of 50%. The gross APR for lending LP into said pool will be: `f(fraxSwapApr, BammBorrowAPR, BammUtility)`

```
grossAPR = ((1 - 0.5) [Idle LP in Bamm] * 3% + 0.5 [utility] * 8%) = 5.5%
```

## Adding Collateral to a Vault
In order to rent the LP which has been deposited in the bamm by lenders, a user must first deposit collateral into their vault in order to rent the underlying Pairs LP tokens. This is done via the [`executeActions()` function](src/contracts/BAMM.sol#L324).

Unlike other lending markets in which collateral is denominated in terms of a single currency. Collateral in the BAMM is denominated in terms of the square root of the product of `token0` and `token1` present w/n a given users vault.

In the graph below: 
- `Z-axis` represents the credited collateral for a given vault.
- `X-axis` represents the amount of `token0` present w/n a vault
- `Y-axis` represents the amount of `token1` present w/n a vault 
![Screenshot 2024-11-18 at 2.09.49 PM](https://hackmd-prod-images.s3-ap-northeast-1.amazonaws.com/uploads/upload_e7563081bac059d145650489aa81c15b.png?AWSAccessKeyId=AKIA3XSAAW6AWSKNINWO&Expires=1738260297&Signature=Hpu6FGXx7kiDuO77MlRrQPTULKk%3D)


**Notice**: The Sqrt of the product of `token0` and `token1` decays to zero as either of the balances of `token0` and `token1` approach zero. This means that if a vault has `1000` of `token0` but `0` of `token1` the credited collateral for this vault would be zero. 

Similarly vaults which has collateral concentrated in a high amount of a single tokens will need to provide a greater amount of that token in order to acheive the same amount of borrowing power as a balanced vault.

eg:
```
vault1 BorrowingPower = Math.sqrt(10_000*1) = 100
Vault2 BorrowingPower = Math.sqrt(1_000*10) = 100
Vault3 BorrowingPower = Math.sqrt(100*100) = 100
```

## Renting / Borrowing LP 

Assuming a user has a sufficiently collateralized vault. they are then able to rent LP, via `executeActions(Action)`. If the amount to rent is positive the users vault will be debited the rent amount, and the corresponding LP tokens will be unwound and credited to that users vault.  The user is then able to withdraw borrowed tokens to their wallet for use depending the value of their deposited collateral.

This rent amount corresponds to LP token amount using the formula given below: 
```
RentedReal = (rent * rentedMultiplier) / 1e18
lp = (rentedReal * lp Total Supply) / Math.sqrt(reserveA * reserveB)
```

or alternatively:
```
rentedReal = (lp * Math.sqrt(reserveA * reserveB)) / lp TotalSupply
```


## Solvency


A given users vault in the bamm is said to be solvent so long as:
```
rentedReal = (vault.rented * rentedMultiplier) / 1e18
ltv = (rentedReal * 1e18) / Math.sqrt(vault.token0 * vault.token1) 
ltv > 98%
```

If a users vault is not solvent they are eligible for liquidation.


## Liquidations

Provided that the user's ltv is greater than 98% they will not need to worry about being liquidated. 

If a user's, is greater than 98% They are subject to micro liquidation. This mechanism mimics an action mechanism in the sense that as a users position approaches 99% LTV more of their collateral, `token0` and `token1`, as well as the `LIQUIDATION_FEE` paid to the liquidator will increase.

If a user's position has greater than 99% LTV they are subject to a full liquidation. In which their entire collateral position will be added back to the fraxswap AMM in order to mint LP to cover their debt.


## Swapping
When renting LP from the bamm users are also able to swap the components of the LP to tailor their position exposure to their needs. Users are able to to this via the bamm's:

```
    /// @notice Execute actions and also do a swap
    /// @param action The details of the action to be executed
    /// @param swapParams The details of the swap to be executed
    /// @return vault Ending vault state
    function executeActionsAndSwap(
        Action memory action,
        IFraxswapRouterMultihop.FraxswapParams memory swapParams
    ) public nonReentrant returns (Vault memory vault)
```
This allows for users to either swap the components of their rented LP tokens or swap prior to repaying their rented balances.

<br></br>

# Local Setup & Tooling

## Installation
`pnpm i`

## Compile
`forge build`

## Test
`forge test`

`forge test -w` watch for file changes

`forge test -vvv` show stack traces for failed tests

## Deploy
- Update environment variables
  - If deploying to networks other than mainnet/polygon, also update the bottom of `foundry.toml`
- Edit `package.json` scripts of `deploy` to your desired configuration
  - NOTE: to dry-run only, remove all flags after `-vvvv`
- `source .env`


## Tooling
This repo uses the following tools:
- frax-standard-solidity for testing and scripting helpers
- prettier for code formatting
- lint-staged & husky for pre-commit formatting checks
- solhint for code quality and style hints
- foundry for compiling, testing, and deploying

## Additional Tooling


### Running Certora Prover

- Ensure that you have python, JDK, and solc installed on your machine.
```
python --version
> Python 3.13.0

java --version
> openjdk 23.0.1 2024-10-15
> OpenJDK Runtime Environment Homebrew (build > 23.0.1)
> OpenJDK 64-Bit Server VM Homebrew (build 23.0.1, mixed mode, sharing)

solc --version
> solc, the solidity compiler commandline interface
> Version: 0.8.23+commit.f704f362.Darwin.appleclang
```

- Install the `certora-cli`
```
pip install certora-cli
```

- Export your certora API Key, found [here](https://www.certora.com/)
```
 CERTORAKEY="000000...."
```

- Run the certora Prover with a specificed config file passed, eg:
```
certoraRun certora/confs/BAMM-1.conf --solc solc
```

- You can optionally install the Certora Verification Language [(LSP)](https://marketplace.visualstudio.com/items?itemName=Certora.evmspec-lsp) for syntax highlighting for `.spec` files


***

### Running Slither
- Install via python: 
```
pip install slither-analyzer
```

- To run on repo (cwd should be root):
```
slither .
```


## Contributing
We welcome all contributions. Please feel free to open a PR and someone at the organization will reach out to coordinate the merge.