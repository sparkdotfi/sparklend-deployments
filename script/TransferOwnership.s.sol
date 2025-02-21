// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import "forge-std/StdJson.sol";
import "forge-std/console.sol";

import {DeployHyFiUtils} from "src/deployments/utils/DeployHyFiUtils.sol";
import {DeployUtils} from "src/deployments/utils/DeployUtils.sol";

contract TransferOwnership is DeployHyFiUtils, Script {
    using stdJson for string;

    uint256 instanceIdBlock = 0;
    string rpcUrl;
    uint256 forkBlock;
    uint256 initialReserveCount;

    function run() external {
        instanceId = vm.envOr("INSTANCE_ID", string("primary"));
        vm.setEnv("FOUNDRY_ROOT_CHAINID", vm.toString(block.chainid));

        config = DeployUtils.readInput(instanceId);
        admin = config.readAddress(".admin");
        if (instanceIdBlock > 0) {
            deployedContracts = DeployUtils.readOutput(instanceId, instanceIdBlock);
        } else {
            deployedContracts = DeployUtils.readOutput(instanceId);
        }

        _setContractAddresses();

        address[] memory tokens;
        address[] memory oracles;

        console.log("HypurrFi Mainnet Reserve Config");
        console.log("sender", msg.sender);

        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));

        _transferOwnership();

        vm.stopBroadcast();
    }
}
