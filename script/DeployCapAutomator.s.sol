// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Script} from 'forge-std/Script.sol';
import {ScriptTools} from "dss-test/ScriptTools.sol";
import 'forge-std/StdJson.sol';
import 'forge-std/console.sol';

import {CapAutomator} from 'src/contracts/dependencies/sparklend/CapAutomator.sol';
import {IPoolAddressesProvider} from "aave-v3-core/contracts/interfaces/IPoolAddressesProvider.sol";

contract Default is Script {
  using stdJson for string;
  using ScriptTools for string;

  string deployedContracts;
  string instanceId;

  IPoolAddressesProvider poolAddressesProvider;
  CapAutomator capAutomator;

  function run() external {
    console.log('Aave V3 Cap Automator Deployment');
    console.log('sender', msg.sender);
    console.log('chainid', block.chainid);

    instanceId = vm.envOr("INSTANCE_ID", string("primary"));
    vm.setEnv("FOUNDRY_ROOT_CHAINID", vm.toString(block.chainid));
        
    deployedContracts = ScriptTools.readOutput(instanceId);
        
    poolAddressesProvider = IPoolAddressesProvider(deployedContracts.readAddress(".poolAddressesProvider"));

    vm.startBroadcast(vm.envUint('PRIVATE_KEY'));

    capAutomator = new CapAutomator(address(poolAddressesProvider));
    
    vm.stopBroadcast();

    ScriptTools.exportContract(string(abi.encodePacked(instanceId, "-capAutomator")), "capAutomator", address(capAutomator));
  }
}