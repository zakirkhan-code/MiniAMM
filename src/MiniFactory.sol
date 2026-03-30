// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./MiniPair.sol";

contract MiniFactory {

    mapping(address => mapping(address => address)) public getPair;

    /// @notice Array of all pairs ever created
    address[] public allPairs;

    address public feeTo;
    address public feeToSetter;

    event PairCreated(
        address indexed token0,
        address indexed token1,
        address pair,
        uint256 pairIndex
    );

    constructor(address _feeToSetter) {
        feeToSetter = _feeToSetter;
    }

    function allPairsLength() external view returns (uint256) {
        return allPairs.length;
    }

    function createPair(address tokenA, address tokenB)
        external returns (address pair)
    {
        // Check 1: Tokens must be different
        require(tokenA != tokenB, "MiniFactory: IDENTICAL_ADDRESSES");

        (address token0, address token1) = tokenA < tokenB
            ? (tokenA, tokenB)
            : (tokenB, tokenA);

        require(token0 != address(0), "MiniFactory: ZERO_ADDRESS");

        require(getPair[token0][token1] == address(0), "MiniFactory: PAIR_EXISTS");

        bytes memory bytecode = type(MiniPair).creationCode;
        bytes32 salt = keccak256(abi.encodePacked(token0, token1));

        assembly {
            pair := create2(0, add(bytecode, 32), mload(bytecode), salt)
        }

        require(pair != address(0), "MiniFactory: DEPLOY_FAILED");

        MiniPair(pair).initialize(token0, token1);

        getPair[token0][token1] = pair;
        getPair[token1][token0] = pair;

        allPairs.push(pair);

        emit PairCreated(token0, token1, pair, allPairs.length);
    }

    function setFeeTo(address _feeTo) external {
        require(msg.sender == feeToSetter, "MiniFactory: FORBIDDEN");
        feeTo = _feeTo;
    }

    function setFeeToSetter(address _feeToSetter) external {
        require(msg.sender == feeToSetter, "MiniFactory: FORBIDDEN");
        feeToSetter = _feeToSetter;
    }
}