// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Script} from 'forge-std/Script.sol';
import 'forge-std/StdJson.sol';
import 'forge-std/console.sol';

import {HyperTestnetReservesConfigs} from 'src/deployments/configs/HyperTestnetReservesConfigs.sol';
import {ScriptTools} from "dss-test/ScriptTools.sol";

contract ConfigurrHypurrReserves is HyperTestnetReservesConfigs, Script {
  using stdJson for string;

  string  instanceId = "hypurrfi-testnet";
  uint256 instanceIdBlock = 0;
  string  rpcUrl;
  uint256 forkBlock;
  uint256 initialReserveCount;

  string config;
  string deployedContracts;

  function run() external {
    vm.setEnv("FOUNDRY_ROOT_CHAINID", vm.toString(block.chainid));
  
    config            = ScriptTools.readInput(instanceId);
    if (instanceIdBlock > 0) {
      deployedContracts = ScriptTools.readOutput(instanceId, instanceIdBlock);
    } else {
      deployedContracts = ScriptTools.readOutput(instanceId);
    }

    _setDeployRegistry(deployedContracts);

    address[] memory tokens;
    address[] memory oracles;

    console.log('HypurrFi Testnet Reserve Config');
    console.log('sender', msg.sender);

    vm.startBroadcast(vm.envUint('PRIVATE_KEY'));

    tokens = _fetchTestnetTokens();

    oracles = _fetchTestnetOracles();

    // set oracles
    _getAaveOracle().setAssetSources(tokens, oracles);

    // set reserve config
    _initReserves(tokens);

    _enableCollateral(tokens);
    
    // enable borrowing
    _enableBorrowing(tokens);

    vm.stopBroadcast();
  }
}