// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.10;

import "forge-std/Script.sol";
import {stdJson} from "forge-std/StdJson.sol";
import {DeployUtils} from "src/deployments/utils/DeployUtils.sol";

import {WHYPE} from "src/tokens/WHYPE.sol";

contract DeployPoolImplementation is Script {

    using stdJson for string;
    using DeployUtils for string;

    string deployedContracts;
    string instanceId;

    WHYPE whype;

    function run() external {
        //vm.createSelectFork(vm.envString("ETH_RPC_URL"));     // Multi-chain not supported in Foundry yet (use CLI arg for now)
        instanceId = vm.envOr("INSTANCE_ID", string("primary"));
        vm.setEnv("FOUNDRY_ROOT_CHAINID", vm.toString(block.chainid));

        vm.startBroadcast(vm.envUint('PRIVATE_KEY'));

        whype = new WHYPE();

        vm.stopBroadcast();

        DeployUtils.exportContract(string(abi.encodePacked(instanceId, "-WHYPE")), "wrappedHype", address(whype));
    }
}
