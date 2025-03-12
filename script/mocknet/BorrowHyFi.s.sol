pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import "forge-std/StdJson.sol";
import "forge-std/console.sol";

import {HyperMocknetReservesConfigs} from "src/deployments/configs/HyperMocknetReservesConfigs.sol";
import {DeployUtils} from "src/deployments/utils/DeployUtils.sol";

contract Default is HyperMocknetReservesConfigs, Script {
    using stdJson for string;

    string instanceId;
    uint256 instanceIdBlock = 0;
    string rpcUrl;
    uint256 forkBlock;
    uint256 initialReserveCount;

    string config;
    string deployedContracts;

  function run() external {
    instanceId = vm.envOr("INSTANCE_ID", string("primary"));
    vm.setEnv("FOUNDRY_ROOT_CHAINID", vm.toString(block.chainid));

    config = DeployUtils.readInput(instanceId);
    if (instanceIdBlock > 0) {
        deployedContracts = DeployUtils.readOutput(instanceId, instanceIdBlock);
    } else {
        deployedContracts = DeployUtils.readOutput(instanceId);
    }

    _setDeployRegistry(deployedContracts);
    address[] memory tokens = new address[](1);

    tokens[0] = deployedContracts.readAddress(".usdc");

    uint256[] memory amounts = new uint256[](1);

    amounts[0] = 8250e6;

    address[] memory recipients = new address[](1);

    recipients[0] = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;

    console.log('Aave V3 Last Testnet Token Fauceting');
    console.log('sender', vm.envAddress("SENDER"));

    vm.startBroadcast(vm.envUint('PRIVATE_KEY'));

    _borrowFromPool(
        tokens,
        amounts,
        vm.envAddress("SENDER")
    );

    vm.stopBroadcast();
  }
}