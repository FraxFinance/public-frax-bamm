// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import { ERC20Permit, ERC20 } from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";

contract ERC20Mock is ERC20Permit {
    constructor(string memory name_, string memory symbol_) ERC20Permit(name_) ERC20(name_, symbol_) {}

    function mint(address account, uint256 value) external {
        _mint({ account: account, value: value });
    }

    function burn(address account, uint256 value) external {
        _burn({ account: account, value: value });
    }
}
