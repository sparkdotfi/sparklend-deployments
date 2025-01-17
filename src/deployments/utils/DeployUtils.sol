// SPDX-License-Identifier: AGPL-3.0
pragma solidity >=0.8.0;

import { stdJson } from "forge-std/StdJson.sol";
import { VmSafe } from "forge-std/Vm.sol";
import { IERC20Metadata } from "src/contracts/dependencies/openzeppelin/interfaces/IERC20Metadata.sol";

library DeployUtils {
    VmSafe private constant vm = VmSafe(address(uint160(uint256(keccak256("hevm cheat code")))));
    string internal constant EXPORT_JSON_KEY = "EXPORTS";

    function getRootChainId() internal view returns (uint256) {
        return vm.envUint("FOUNDRY_ROOT_CHAINID");
    }

    function readInput(string memory name) internal view returns (string memory) {
        string memory root = vm.projectRoot();
        return readInput(root, name);
    }

    function readInput(string memory root, string memory name) internal view returns (string memory) {
        string memory chainInputFolder = string(abi.encodePacked("/script/input/", vm.toString(getRootChainId()), "/"));
        return vm.readFile(string(abi.encodePacked(root, chainInputFolder, name, ".json")));
    }

    function readOutput(string memory name, uint256 timestamp) internal view returns (string memory) {
        string memory root = vm.projectRoot();
        string memory chainOutputFolder = string(abi.encodePacked("/script/output/", vm.toString(getRootChainId()), "/"));
        return vm.readFile(string(abi.encodePacked(root, chainOutputFolder, name, "-", vm.toString(timestamp), ".json")));
    }

    function readOutput(string memory name) internal view returns (string memory) {
        string memory root = vm.projectRoot();
        string memory chainOutputFolder = string(abi.encodePacked("/script/output/", vm.toString(getRootChainId()), "/"));
        return vm.readFile(string(abi.encodePacked(root, chainOutputFolder, name, "-latest.json")));
    }

    function readTokenConfig(address token) internal view returns (string memory) {
      // Read JSON file from script/inputs/{chainId}/{tokenSymbol}.json
      string memory chainInputFolder = string(abi.encodePacked("./script/input/", vm.toString(getRootChainId()), "/assets/"));
      string memory tokenConfigPath = string(abi.encodePacked(chainInputFolder, IERC20Metadata(token).symbol(), ".json"));
      return vm.readFile(tokenConfigPath);
    }

    /**
     * @notice Use standard environment variables to load config.
     * @dev Will first check FOUNDRY_SCRIPT_CONFIG_TEXT for raw json text.
     *      Falls back to FOUNDRY_SCRIPT_CONFIG for a standard file definition.
     *      Finally will fall back to the given string `name`.
     * @param name The default config file to load if no environment variables are set.
     * @return config The raw json text of the config.
     */
    function loadConfig(string memory name) internal returns (string memory config) {
        config = vm.envOr("FOUNDRY_SCRIPT_CONFIG_TEXT", string(""));
        if (eq(config, "")) {
            config = readInput(vm.envOr("FOUNDRY_SCRIPT_CONFIG", name));
        }
    }
    
    /**
     * @notice Use standard environment variables to load config.
     * @dev Will first check FOUNDRY_SCRIPT_CONFIG_TEXT for raw json text.
     *      Falls back to FOUNDRY_SCRIPT_CONFIG for a standard file definition.
     *      Finally will revert if no environment variables are set.
     * @return config The raw json text of the config.
     */
    function loadConfig() internal returns (string memory config) {
        config = vm.envOr("FOUNDRY_SCRIPT_CONFIG_TEXT", string(""));
        if (eq(config, "")) {
            config = readInput(vm.envString("FOUNDRY_SCRIPT_CONFIG"));
        }
    }

    /**
     * @notice Used to export important contracts to higher level deploy scripts.
     *         Note waiting on Foundry to have better primitives, but roll our own for now.
     * @dev Set FOUNDRY_EXPORTS_NAME to override the name of the json file.
     * @param name The name to give the json file.
     * @param label The label of the address.
     * @param addr The address to export.
     */
    function exportContract(string memory name, string memory label, address addr) internal {
        name = vm.envOr("FOUNDRY_EXPORTS_NAME", name);
        string memory json = vm.serializeAddress(EXPORT_JSON_KEY, label, addr);
        string memory root = vm.projectRoot();
        string memory chainOutputFolder = string(abi.encodePacked("/script/output/", vm.toString(getRootChainId()), "/"));
        vm.writeJson(json, string(abi.encodePacked(root, chainOutputFolder, name, "-", vm.toString(block.timestamp), ".json")));
        vm.writeJson(json, string(abi.encodePacked(root, chainOutputFolder, name, "-", "latest", ".json")));
        if (vm.envOr("FOUNDRY_EXPORTS_OVERWRITE_LATEST", false)) {
            vm.writeJson(json, string(abi.encodePacked(root, chainOutputFolder, name, "-latest.json")));
        }
    }

    function eq(string memory a, string memory b) internal pure returns (bool) {
        return keccak256(bytes(a)) == keccak256(bytes(b));
    }
}