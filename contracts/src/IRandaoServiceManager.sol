// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

struct Task {
    uint128 createdAtBlock;
    uint128 blockNumber;
    uint256 blockDifficulty;
}

interface IRandaoServiceManager {
    event OperatorSlashed(uint32 indexed _index, Task _task, address _operator, address _slasher);
    event TaskCreated(uint32 indexed _index, Task _task, address _consumer);
    event TaskRespondedTo(uint32 indexed _index, Task _task, address _operator);
    event TaskVerified(uint32 indexed _index, Task _task, address _verifier);

    error AlreadyResponded();
    error AlreadyVerified();
    error BlockNotMined();
    error InsufficientWeight();
    error InvalidBlockNumber();
    error InvalidSlasher();
    error InvalidSignature();
    error InvalidTask();
    error SlashedOperator();
    error UnregisteredOperator();

    function createTask(uint256 _blockNumber) external;

    function respondToTask(uint32 _index, Task memory _task, uint256 _blockDifficulty, bytes calldata _signature) external;

    function verifyTask(uint32 _index, Task calldata _task, address _operator, uint256 _blockDifficulty) external;

    function hasMinWeight(address _operator) external view returns (bool);

    function isRegisteredOperator(address _caller) external view returns (bool);

    function getSigner(uint128 _blockNumber, uint256 _blockDifficulty, bytes memory _signature) external pure returns (address);

    function getTaskHash(Task memory _task) external pure returns (bytes32);
}