// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import {RandaoServiceManager} from "../src/RandaoServiceManager.sol";
import {IRandaoServiceManager} from "../src/IRandaoServiceManager.sol";

import {MockAVSDeployer} from "@eigenlayer-middleware/test/utils/MockAVSDeployer.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

contract RandaoTaskManagerTest is MockAVSDeployer {}
