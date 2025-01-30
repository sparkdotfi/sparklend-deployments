pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import "forge-std/StdJson.sol";
import "forge-std/console.sol";

import {HyperTestnetReservesConfigs} from "src/deployments/configs/HyperTestnetReservesConfigs.sol";
import {DeployUtils} from "src/deployments/utils/DeployUtils.sol";

contract Default is HyperTestnetReservesConfigs, Script {
    using stdJson for string;

    string instanceId = "hypurrfi-testnet";
    uint256 instanceIdBlock = 0;
    string rpcUrl;
    uint256 forkBlock;
    uint256 initialReserveCount;

    string config;
    string deployedContracts;

  function run() external {
    vm.setEnv("FOUNDRY_ROOT_CHAINID", vm.toString(block.chainid));

    config = DeployUtils.readInput(instanceId);
    if (instanceIdBlock > 0) {
        deployedContracts = DeployUtils.readOutput(instanceId, instanceIdBlock);
    } else {
        deployedContracts = DeployUtils.readOutput(instanceId);
    }

    _setDeployRegistry(deployedContracts);
    address[] memory tokens = new address[](2);

    tokens[0] = 0x6fDbAF3102eFC67ceE53EeFA4197BE36c8E1A094; // USDC
    tokens[1] = 0x2222C34A8dd4Ea29743bf8eC4fF165E059839782; // sUSDe

    uint256[] memory amounts = new uint256[](3);

    amounts[0] = 10e6;
    amounts[1] = 10e18;

    address[] memory recipients = new address[](1);

    recipients[0] = 0xE0157B2E81506f7710e62b331eb113B232e89efA;

    console.log('Aave V3 Last Testnet Token Fauceting');
    console.log('sender', msg.sender);

    vm.startBroadcast(vm.envUint('PRIVATE_KEY'));

    // _faucetTokens(
    //    tokens,
    //    amounts,
    //    recipients 
    // );

    _supplyPool(
        tokens,
        amounts,
        vm.envAddress('SENDER')
    );

    vm.stopBroadcast();
  }
}