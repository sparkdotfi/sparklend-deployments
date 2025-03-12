// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.10;

import "forge-std/Script.sol";
import {stdJson} from "forge-std/StdJson.sol";
import {DeployUtils} from "src/deployments/utils/DeployUtils.sol";
import {DeployHyFiUtils} from "src/deployments/utils/DeployHyFiUtils.sol";

contract DeployHyFi is Script, DeployHyFiUtils {
    using stdJson for string;
    using DeployUtils for string;

    function run() external {
        instanceId = vm.envOr("INSTANCE_ID", string("primary"));
        vm.setEnv("FOUNDRY_ROOT_CHAINID", vm.toString(block.chainid));

        config = DeployUtils.loadConfig(instanceId);

        admin = config.readAddress(".admin");
        deployer = msg.sender;

        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));
        _deployHyFi(true);
        vm.stopBroadcast();

        DeployUtils.exportContract(instanceId, "hyTokenImpl", address(hyTokenImpl));
        DeployUtils.exportContract(instanceId, "hyFiOracle", address(hyFiOracle));
        DeployUtils.exportContract(instanceId, "aclManager", address(aclManager));
        DeployUtils.exportContract(instanceId, "admin", address(admin));
        DeployUtils.exportContract(instanceId, "deployer", address(deployer));
        DeployUtils.exportContract(instanceId, "emissionManager", address(emissionManager));
        DeployUtils.exportContract(instanceId, "incentives", address(incentivesProxy));
        DeployUtils.exportContract(instanceId, "incentivesImpl", address(rewardsController));
        DeployUtils.exportContract(instanceId, "pool", address(pool));

        DeployUtils.exportContract(instanceId, "poolAddressesProvider", address(poolAddressesProvider));
        DeployUtils.exportContract(instanceId, "poolAddressesProviderRegistry", address(registry));

        DeployUtils.exportContract(instanceId, "poolConfigurator", address(poolConfigurator));
        DeployUtils.exportContract(instanceId, "poolConfiguratorImpl", address(poolConfiguratorImpl));
        DeployUtils.exportContract(instanceId, "poolImpl", address(poolImpl));
        DeployUtils.exportContract(instanceId, "protocolDataProvider", address(protocolDataProvider));
        DeployUtils.exportContract(instanceId, "disabledStableDebtTokenImpl", address(disabledStableDebtTokenImpl));
        DeployUtils.exportContract(instanceId, "treasury", address(treasury));
        DeployUtils.exportContract(instanceId, "treasuryController", address(treasuryController));
        DeployUtils.exportContract(instanceId, "treasuryImpl", address(treasuryImpl));
        DeployUtils.exportContract(instanceId, "uiIncentiveDataProvider", address(uiIncentiveDataProvider));
        DeployUtils.exportContract(instanceId, "uiPoolDataProvider", address(uiPoolDataProvider));
        DeployUtils.exportContract(instanceId, "variableDebtTokenImpl", address(variableDebtTokenImpl));
        DeployUtils.exportContract(instanceId, "walletBalanceProvider", address(walletBalanceProvider));
        DeployUtils.exportContract(instanceId, "wrappedHypeGateway", address(wrappedHypeGateway));
        DeployUtils.exportContract(instanceId, "defaultInterestRateStrategy", address(interestRateStrategy));
    }
}
