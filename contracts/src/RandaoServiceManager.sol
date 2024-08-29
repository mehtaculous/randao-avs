// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import {BytesLib} from  "@eigenlayer/contracts/libraries/BytesLib.sol";
import {DelegationManager} from "@eigenlayer/contracts/core/DelegationManager.sol";
import {ECDSAServiceManagerBase} from "@eigenlayer-middleware/src/unaudited/ECDSAServiceManagerBase.sol";
import {ECDSAStakeRegistry} from "@eigenlayer-middleware/src/unaudited/ECDSAStakeRegistry.sol";
import {ECDSAUpgradeable} from "@openzeppelin-upgrades/contracts/utils/cryptography/ECDSAUpgradeable.sol";
import {Pausable} from "@eigenlayer/contracts/permissions/Pausable.sol";

import {IRegistryCoordinator} from "@eigenlayer-middleware/src/interfaces/IRegistryCoordinator.sol";
import {IRandaoServiceManager, Task} from "./IRandaoServiceManager.sol";

contract RandaoServiceManager is
    IRandaoServiceManager,
    ECDSAServiceManagerBase,
    Pausable
{
    using BytesLib for bytes;
    using ECDSAUpgradeable for bytes32;
    
    uint32 public currentIndex;
    mapping(uint32 => bytes32) public tasks;
    mapping(address => mapping(uint32 => bytes)) public responses;
    mapping(uint32 => bool) public verified;
    mapping(address => bool) public slashed;
    
    modifier onlyOperator() {
        if (!isRegisteredOperator(msg.sender)) revert UnregisteredOperator();
        if (!hasMinWeight(msg.sender)) revert InsufficientWeight();
        if (slashed[msg.sender]) revert InvalidOperator();
        _;
    }

    constructor(address _avsDirectory, address _stakeRegistry, address _delegationManager)
        ECDSAServiceManagerBase(
            _avsDirectory,
            _stakeRegistry,
            address(0),
            _delegationManager
        )
    {}

    function createTask(uint256 _blockNumber) external {
        if (block.number >= _blockNumber) revert InvalidBlockNumber();
        
        Task memory task;
        task.createdAtBlock = uint128(block.number);
        task.blockNumber = uint128(_blockNumber);
        tasks[++currentIndex] = getTaskHash(task);
        
        emit TaskCreated(currentIndex, task, msg.sender);
    }

    function respondToTask(uint32 _index, Task calldata _task, uint256 _blockDifficulty, bytes calldata _signature) external onlyOperator {
        if (getTaskHash(_task) != tasks[_index]) revert InvalidTask();
        if (responses[msg.sender][_index].length != 0) revert AlreadyResponded();
        if (block.number < _task.blockNumber) revert BlockNotMined();
        if (getSigner(_task.blockNumber, _blockDifficulty, _signature) != msg.sender) revert InvalidSignature();

        responses[msg.sender][_index] = _signature;

        emit TaskRespondedTo(_index, _task, msg.sender);
    }
    
    function verifyTask(uint32 _index, Task calldata _task, address _operator, uint256 _blockDifficulty) external onlyOperator {
        if (msg.sender == _operator) revert InvalidSlasher();
        if (getTaskHash(_task) != tasks[_index]) revert InvalidTask();
        if (verified[_index] || slashed[_operator]) revert AlreadyVerified();
        
        bytes memory signature = responses[_operator][_index];
        if (getSigner(_task.blockNumber, _blockDifficulty, signature) != _operator) {
            slashed[_operator] = true;
            emit OperatorSlashed(_index, _task, _operator, msg.sender);
        } else {
            verified[_index] = true;
            emit TaskVerified(_index, _task, msg.sender);
        }
    }

    function hasMinWeight(address _operator) public view returns (bool) {
        return ECDSAStakeRegistry(stakeRegistry).getOperatorWeight(_operator) >= ECDSAStakeRegistry(stakeRegistry).minimumWeight();
    }

    function isRegisteredOperator(address _caller) public view returns (bool) {
        return ECDSAStakeRegistry(stakeRegistry).operatorRegistered(_caller);
    }

    function getSigner(uint128 _blockNumber, uint256 _blockDifficulty, bytes memory _signature) public pure returns (address) {
        bytes32 messageHash = keccak256(abi.encodePacked(_blockNumber, _blockDifficulty));
        bytes32 ethSignedMessageHash = messageHash.toEthSignedMessageHash();
        return ethSignedMessageHash.recover(_signature);
    }

    function getTaskHash(Task memory _task) public pure returns (bytes32) {
        return keccak256(abi.encode(_task));
    }
}