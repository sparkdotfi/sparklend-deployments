pragma solidity >=0.8.0;

import { stdJson } from "forge-std/StdJson.sol";
import { VmSafe } from "forge-std/Vm.sol";
import { IERC20Metadata } from "src/contracts/dependencies/openzeppelin/interfaces/IERC20Metadata.sol";

library DeployUtils {
    VmSafe private constant vm = VmSafe(address(uint160(uint256(keccak256("hevm cheat code")))));
    

    function getRootChainId() internal view returns (uint256) {
        return vm.envUint("FOUNDRY_ROOT_CHAINID");
    }

    function readTokenConfig(address token) internal view returns (string memory) {
      // Read JSON file from script/inputs/{chainId}/{tokenSymbol}.json
      string memory chainInputFolder = string(abi.encodePacked("./script/input/", vm.toString(getRootChainId()), "/assets/"));
      string memory tokenConfigPath = string(abi.encodePacked(chainInputFolder, IERC20Metadata(token).symbol(), ".json"));
      return vm.readFile(tokenConfigPath);
    }
}