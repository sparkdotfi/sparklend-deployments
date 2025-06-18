// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import "forge-std/StdJson.sol";
import "forge-std/console.sol";

import {HyperMainnetReservesConfigs} from "src/deployments/configs/HyperMainnetReservesConfigs.sol";
import {DeployUtils} from "src/deployments/utils/DeployUtils.sol";
import {IERC20} from "@aave/core-v3/contracts/dependencies/openzeppelin/contracts/IERC20.sol";
import {ERC20} from "@aave/core-v3/contracts/dependencies/openzeppelin/contracts/ERC20.sol";
import {ILiquidator} from "src/periphery/contracts/misc/interfaces/ILiquidator.sol";
import {IUiPoolDataProviderV3} from '@aave/periphery-v3/contracts/misc/interfaces/IUiPoolDataProviderV3.sol';
import {IPoolAddressesProvider} from "aave-v3-core/contracts/interfaces/IPoolAddressesProvider.sol";

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

        console.log("HypurrFi Mainnet Reserve Config");
        console.log("sender", msg.sender);

        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));

        // USDXL approving address of pool
        // IERC20(0xca79db4B49f608eF54a5CB813FbEd3a6387bC645).approve(0xceCcE0EB9DD2Ef7996e01e25DD70e461F918A14b, type(uint256).max);
        // ILiquidator(0x7A5e5837F23460f32BAcc916C74FF2a608f74375).approvePool(0xca79db4B49f608eF54a5CB813FbEd3a6387bC645);
        ERC20(0x9FDBdA0A5e284c32744D2f17Ee5c74B284993463).decimals();
        
        // stack too deep :(
        // IUiPoolDataProviderV3(0x7b883191011AEAe40581d3Fa1B112413808C9c00).getReservesData(IPoolAddressesProvider(0xA73ff12D177D8F1Ec938c3ba0e87D33524dD5594));

        vm.stopBroadcast();
    }
}
