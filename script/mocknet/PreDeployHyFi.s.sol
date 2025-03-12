// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.10;

import "forge-std/Script.sol";
import {stdJson} from "forge-std/StdJson.sol";
import {DeployUtils} from "src/deployments/utils/DeployUtils.sol";

import {WHYPE} from "src/tokens/WHYPE.sol";
import {WstHYPEOracle} from "src/contracts/oracle/wstHYPEOracle.sol";
import {MockAggregator} from "aave-v3-core/contracts/mocks/oracle/CLAggregators/MockAggregator.sol";
import {MintableLimitERC20} from "src/testnet/MintableLimitERC20.sol";
import {Vm} from "forge-std/Vm.sol";
import "forge-std/console.sol";

contract PreDeployHyFi is Script {
    using stdJson for string;
    using DeployUtils for string;

    string deployedContracts;
    string instanceId;

    WHYPE whype;
    MockAggregator whypeOracle;
    
    MintableLimitERC20 usdc;
    MockAggregator usdcOracle;

    function run() external {
        //vm.createSelectFork(vm.envString("ETH_RPC_URL"));     // Multi-chain not supported in Foundry yet (use CLI arg for now)
        instanceId = vm.envOr("INSTANCE_ID", string("primary"));
        vm.setEnv("FOUNDRY_ROOT_CHAINID", vm.toString(block.chainid));

        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));

        // script meant for localnet
        if(block.chainid == 1337) {
            usdc = new MintableLimitERC20("USD Coin", "USDC", 6, type(uint256).max);
            usdcOracle = new MockAggregator(1e8);

            whype = new WHYPE();
            whypeOracle = new MockAggregator(10e8);
        }
        vm.stopBroadcast();

        DeployUtils.exportContract(string(abi.encodePacked(instanceId)), "usdc", address(usdc));
        DeployUtils.exportContract(string(abi.encodePacked(instanceId)), "usdcOracle", address(usdcOracle));

        DeployUtils.exportContract(string(abi.encodePacked(instanceId)), "whype", address(whype));
        DeployUtils.exportContract(string(abi.encodePacked(instanceId)), "whypeOracle", address(whypeOracle));
    }
}
