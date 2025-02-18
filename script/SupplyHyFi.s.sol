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
    // address[] memory tokens = new address[](1);

    // tokens[0] = address(0x4B85aCF84b2593D67f6593D18504dBb3A337D3D8); // SolvBTC
    // // tokens[1] = address(0x6fDbAF3102eFC67ceE53EeFA4197BE36c8E1A094); // USDC
    // // tokens[2] = 0x2222C34A8dd4Ea29743bf8eC4fF165E059839782; // sUSDe

    // uint256[] memory amounts = new uint256[](1);

    // amounts[0] = 10e18;
    // // amounts[1] = 10000e6;
    // // amounts[2] = 10000e18;

    // address[] memory recipients = new address[](3);

    // recipients[0] = 0x2fCf555c4C508c2e358F373A4B6E25F8491928b0;
    // recipients[1] = 0xabC4b3c691900d524cbF71d237a9A12FCcea3006;
    // recipients[2] = 0x16D2AD8Cc04888b537bB7B631715335a901B57cA;

    console.log('Aave V3 Last Testnet Token Fauceting');
    console.log('sender', msg.sender);

    vm.startBroadcast(vm.envUint('PRIVATE_KEY'));

    // _faucetTokens(
    //    tokens,
    //    amounts,
    //    recipients,
    //    false // skip transfer to supply pool on behalf of recipient
    // );

    // _supplyPool(
    //     tokens,
    //     amounts,
    //     recipients
    // );

    vm.stopBroadcast();
  }
}