// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import "forge-std/StdJson.sol";
import "forge-std/console.sol";

import {HyperMainnetReservesConfigs} from "src/deployments/configs/HyperMainnetReservesConfigs.sol";
import {DeployUtils} from "src/deployments/utils/DeployUtils.sol";

contract ConfigurrHyFiReserves is HyperMainnetReservesConfigs, Script {
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

        address[] memory tokens;
        address[] memory oracles;

        console.log("HypurrFi Mainnet Reserve Config");
        console.log("sender", msg.sender);

        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));

        tokens = _fetchMainnetTokens(config);

        oracles = _fetchMainnetOracles(config);

        // set oracles
        _getAaveOracle().setAssetSources(tokens, oracles);

        // set reserve config
        _initReserves(tokens);

        // disable stable debt
        _disableStableDebt(tokens);

        // enable collateral
        _enableCollateral(tokens);

        // enable borrowing
        _enableBorrowing(tokens);

        // enable flashloans
        _enableFlashloans(tokens);

        vm.stopBroadcast();
    }
}
