pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import "forge-std/StdJson.sol";
import "forge-std/console.sol";

import {HyperMocknetReservesConfigs} from "src/deployments/configs/HyperMocknetReservesConfigs.sol";
import {DeployUtils} from "src/deployments/utils/DeployUtils.sol";
import {WHYPE} from "src/tokens/WHYPE.sol";
import {IERC20} from "solidity-utils/contracts/oz-common/interfaces/IERC20.sol";
import {ILiquidator} from "src/periphery/contracts/misc/interfaces/ILiquidator.sol";
import {IUniswapV3Factory} from "src/periphery/contracts/misc/interfaces/IUniswapV3Factory.sol";

contract Default is HyperMocknetReservesConfigs, Script {
    using stdJson for string;

    string instanceId;
    uint256 instanceIdBlock = 0;
    string rpcUrl;
    uint256 forkBlock;
    uint256 initialReserveCount;

    uint24 public constant FEE = 3000;

    string config;
    string deployedContracts;

  function run() external {
    instanceId = vm.envOr("INSTANCE_ID", string("primary"));
    vm.setEnv("FOUNDRY_ROOT_CHAINID", vm.toString(block.chainid));

    config = DeployUtils.readInput(instanceId);

    // Start broadcasting transactions
    vm.startBroadcast(vm.envUint("PRIVATE_KEY"));

    ILiquidator(config.readAddress(".liquidator")).testGetAmountIn();

    vm.stopBroadcast();
  }
}