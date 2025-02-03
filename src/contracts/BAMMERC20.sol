// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.23;

import { IBAMMERC20 } from "./interfaces/IBAMMERC20.sol";
import { ERC20Permit, ERC20 } from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

/// @dev supports OZ 5.0 interface
contract BAMMERC20 is IBAMMERC20, ERC20Permit, Ownable {
    /// @notice Additional variables for name lookup
    IERC20Metadata public immutable token0;
    IERC20Metadata public immutable token1;
    string public id;

    constructor(address token0_, address token1_, string memory id_) ERC20("", "") ERC20Permit("") Ownable(msg.sender) {
        id = id_;
        token0 = IERC20Metadata(token0_);
        token1 = IERC20Metadata(token1_);
    }

    function mint(address account, uint256 value) external onlyOwner {
        _mint(account, value);
    }

    function burn(address account, uint256 value) external onlyOwner {
        _burn(account, value);
    }

    // ############################################
    // ############## VIEW OVERRIDES  #############
    // ############################################

    function ticker() internal view returns (string memory) {
        return string.concat(token0.symbol(), "/", token1.symbol());
    }

    function symbol() public view override returns (string memory) {
        return string.concat("BAMM_", ticker());
    }

    function name() public view override returns (string memory) {
        return string.concat("BAMM_", id, "_", ticker(), " Fraxswap V2");
    }
}
