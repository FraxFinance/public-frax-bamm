pragma solidity ^0.8.0;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

interface IBAMMERC20 is IERC20 {
    function mint(address account, uint256 value) external;
    function burn(address account, uint256 value) external;
}
