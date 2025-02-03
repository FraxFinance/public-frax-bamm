// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SSTORE2 } from "solmate/src/utils/SSTORE2.sol";
import { BytesLib } from "solidity-bytes-utils/contracts/BytesLib.sol";
import { Ownable, Ownable2Step } from "@openzeppelin/contracts/access/Ownable2Step.sol";

import { IFraxswapPair } from "dev-fraxswap/src/contracts/core/interfaces/IFraxswapPair.sol";

import "src/contracts/interfaces/IBAMMFactory.sol";
import { BAMM } from "../BAMM.sol";

contract BAMMFactory is IBAMMFactory, Ownable2Step {
    IFraxswapFactory public immutable iFraxswapFactory;
    address public immutable routerMultihop;
    address public immutable fraxswapOracle;
    address public variableInterestRate;

    /// @dev state updated on createBamm()
    mapping(address bamm => bool exists) public isBamm;
    mapping(address pair => address bamm) public pairToBamm;
    address[] public bamms;

    /// @dev storage for contract exceeding the size limit by splitting the creation code into two
    address private contractAddress1;
    address private contractAddress2;

    address public feeTo;

    constructor(
        address _fraxswapFactory,
        address _routerMultihop,
        address _fraxswapOracle,
        address _variableInterestRate,
        address _feeTo
    ) Ownable(msg.sender) {
        iFraxswapFactory = IFraxswapFactory(_fraxswapFactory);
        routerMultihop = _routerMultihop;
        fraxswapOracle = _fraxswapOracle;
        variableInterestRate = _variableInterestRate;
        feeTo = _feeTo;
    }

    /// @notice work-around to set creation code which exceeds the contract size limit
    function setCreationCode(bytes calldata _creationCode) external onlyOwner {
        require(contractAddress1 == address(0));
        if (_creationCode.length > 20_500) {
            bytes memory firstHalf = BytesLib.slice(_creationCode, 0, 20_500);
            bytes memory secondHalf = BytesLib.slice(_creationCode, 20_500, _creationCode.length - 20_500);
            contractAddress1 = SSTORE2.write(firstHalf);
            contractAddress2 = SSTORE2.write(secondHalf);
        } else {
            contractAddress1 = SSTORE2.write(_creationCode);
        }
    }

    /// @notice Semantic version of this contract
    /// @return _major The major version
    /// @return _minor The minor version
    /// @return _patch The patch version
    function version() external pure returns (uint256 _major, uint256 _minor, uint256 _patch) {
        return (0, 5, 2);
    }

    /// @notice Create a BAMM for a given FraxswapPair
    /// @notice Incompatible for fee-on-transfer tokens
    /// @param _pair Address of the Fraxswap-created token pair
    /// @return bamm Address of the newly-created BAMM contract
    function createBamm(address _pair) external returns (address bamm) {
        // require pair to have been created from factory
        address token0 = IFraxswapPair(_pair).token0();
        address token1 = IFraxswapPair(_pair).token1();
        address getPair = iFraxswapFactory.getPair(token0, token1);
        if (_pair != getPair) revert PairNotFromFraxswapFactory();

        // revert if bamm exists for pair
        if (pairToBamm[_pair] != address(0)) revert BammAlreadyCreated();

        uint256 id = bamms.length;

        // Get init code from creation code
        bytes memory creationCode;
        if (contractAddress2 != address(0)) {
            creationCode = BytesLib.concat(SSTORE2.read(contractAddress1), SSTORE2.read(contractAddress2));
        } else {
            creationCode = SSTORE2.read(contractAddress1);
        }
        bytes memory constArgs = abi.encode(
            id,
            _pair,
            routerMultihop,
            fraxswapOracle,
            variableInterestRate,
            30 * 2 * 158_247_046
        );
        bytes memory initCode = abi.encodePacked(creationCode, abi.encode(constArgs));

        // Get Salt
        bytes32 salt = keccak256(abi.encode(id, _pair, routerMultihop, fraxswapOracle));

        /// @solidity memory-safe-assembly
        uint256 size;
        assembly {
            bamm := create2(0, add(initCode, 32), mload(initCode), salt)
            size := extcodesize(bamm)
        }
        if (bamm == address(0)) revert Create2Failed();
        if (size == 0) revert Create2Failed();

        // Update state
        isBamm[bamm] = true;
        pairToBamm[_pair] = bamm;
        bamms.push(bamm);

        emit BammCreated(_pair, bamm);
    }

    function bammsArray() external view returns (address[] memory) {
        return bamms;
    }

    function bammsLength() external view returns (uint256) {
        return bamms.length;
    }

    function setFeeTo(address _feeTo) external onlyOwner {
        feeTo = _feeTo;
    }

    function setVariableInterestRate(address newVariableInterestRate) external onlyOwner {
        variableInterestRate = newVariableInterestRate;
    }

    function setBAMMVariableInterestRate(address bamm, address newVariableInterestRate) external onlyOwner {
        if (!isBamm[bamm]) revert NotBAMM();
        BAMM(bamm).setVariableInterestRate(newVariableInterestRate);
    }

    function setBammMaxOracleDiff(address bamm, uint256 newMaxOracleDiff) external onlyOwner {
        if (!isBamm[bamm]) revert NotBAMM();
        BAMM(bamm).setMaxOracleDeviation(newMaxOracleDiff);
    }
}
