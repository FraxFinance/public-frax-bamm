// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

// ====================================================================
// |     ______                   _______                             |
// |    / _____________ __  __   / ____(_____  ____ _____  ________   |
// |   / /_  / ___/ __ `| |/_/  / /_  / / __ \/ __ `/ __ \/ ___/ _ \  |
// |  / __/ / /  / /_/ _>  <   / __/ / / / / / /_/ / / / / /__/  __/  |
// | /_/   /_/   \__,_/_/|_|  /_/   /_/_/ /_/\__,_/_/ /_/\___/\___/   |
// |                                                                  |
// ====================================================================
// ======================== FraxswapDummyRouter =======================
// ====================================================================
// A dummy router that takes in the input tokens and transfers out the amountOutMinimum

import { TransferHelper } from "@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol";

contract FraxswapDummyRouter {
    struct FraxswapParams {
        address tokenIn;
        uint256 amountIn;
        address tokenOut;
        uint256 amountOutMinimum;
        address recipient;
        uint256 deadline;
        bool approveMax;
        uint8 v;
        bytes32 r;
        bytes32 s;
        bytes route;
    }

    function swap(FraxswapParams memory params) external payable returns (uint256) {
        TransferHelper.safeTransferFrom(params.tokenIn, msg.sender, address(this), params.amountIn);
        TransferHelper.safeTransferFrom(params.tokenOut, address(this), params.recipient, params.amountOutMinimum);
        return params.amountOutMinimum;
    }
}
