// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {DeployUtils} from "src/deployments/utils/DeployUtils.sol";
import "forge-std/StdJson.sol";
import "forge-std/console.sol";

import {L2Encoder} from "aave-v3-core/contracts/misc/L2Encoder.sol";
import {IPool} from "aave-v3-core/contracts/interfaces/IPool.sol";
import {Multicall3} from "src/contracts/dependencies/multicall3/Multicall3.sol";

contract Default is Script {
    using stdJson for string;
    using DeployUtils for string;

    string deployedContracts;
    string instanceId;

    IPool pool;
    L2Encoder l2encoder;
    Multicall3 multicall3;

    address admin;
    address deployer;
    string config;

    function run() external {
        console.log("Aave V3 Cap Automator Deployment");
        console.log("sender", msg.sender);
        console.log("chainid", block.chainid);

        instanceId = vm.envOr("INSTANCE_ID", string("primary"));
        vm.setEnv("FOUNDRY_ROOT_CHAINID", vm.toString(block.chainid));

        config = DeployUtils.loadConfig(instanceId);

        admin = config.readAddress(".admin");
        deployer = msg.sender;

        deployedContracts = DeployUtils.readOutput(instanceId);

        pool = IPool(deployedContracts.readAddress(".pool"));

        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));

        // l2encoder = new L2Encoder(pool);
        multicall3 = new Multicall3();
        vm.stopBroadcast();

        // DeployUtils.exportContract(
        //     string(abi.encodePacked(instanceId)), "l2encoder", address(l2encoder)
        // );

        DeployUtils.exportContract(
            string(abi.encodePacked(instanceId)), "multicall3", address(multicall3)
        );
    }
}
