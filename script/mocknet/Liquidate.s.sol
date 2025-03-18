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
    if (instanceIdBlock > 0) {
        deployedContracts = DeployUtils.readOutput(instanceId, instanceIdBlock);
    } else {
        deployedContracts = DeployUtils.readOutput(instanceId);
    }

    _setDeployRegistry(deployedContracts);

    // Start broadcasting transactions
    vm.startBroadcast(vm.envUint("PRIVATE_KEY"));

    // Get the lending pool address from deployed contracts
    address lendingPool = deployedContracts.readAddress(".pool");
    
    // Get the collateral token and debt token addresses
    address collateralToken = deployedContracts.readAddress(".whype");  
    address debtToken = deployedContracts.readAddress(".usdc");
    
    // Specify the user to liquidate
    address userToLiquidate = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;  // Replace with actual user address
    
    uint256 debtToCover = 8550302938;
    // Perform the liquidation
    // Typically liquidation involves:
    // 1. Approving the lending pool to spend your tokens
    // 2. Calling the liquidation function

    IERC20(collateralToken).transfer(config.readAddress(".liquidator"), 2000e18);
    
    // approve the pool
    ILiquidator(config.readAddress(".liquidator")).approvePool(debtToken);
    
    // Call liquidation function - adjust parameters based on your protocol's implementation
    ILiquidator(config.readAddress(".liquidator")).liquidate(
        collateralToken,
        debtToken,
        userToLiquidate,
        debtToCover,
        0, // collateralToReceive
        config.readAddress(".liquidator"),
        false,
        abi.encodePacked(IERC20(debtToken), uint24(FEE), IERC20(collateralToken)) // NOTE: path is reversed for exact output
    );

    vm.stopBroadcast();
  }
}