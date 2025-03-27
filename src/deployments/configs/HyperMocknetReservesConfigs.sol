// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import {ConfiguratorInputTypes} from "@aave/core-v3/contracts/protocol/libraries/types/ConfiguratorInputTypes.sol";
import {DataTypes} from "aave-v3-core/contracts/protocol/libraries/types/DataTypes.sol";
import {IPoolConfigurator} from "@aave/core-v3/contracts/interfaces/IPoolConfigurator.sol";
import {DeployUtils} from "../utils/DeployUtils.sol";
import {MockAggregator} from "aave-v3-core/contracts/mocks/oracle/CLAggregators/MockAggregator.sol";
import {MintableLimitERC20} from "src/testnet/MintableLimitERC20.sol";
import {FaucetReceiver} from "src/testnet/FaucetReceiver.sol";
import {WrappedTokenGatewayV3} from "aave-v3-periphery/misc/WrappedTokenGatewayV3.sol";
import {IAaveOracle} from "aave-v3-core/contracts/interfaces/IAaveOracle.sol";
import {IPoolConfigurator} from "aave-v3-core/contracts/interfaces/IPoolConfigurator.sol";
import {ReserveConfiguration} from "aave-v3-core/contracts/protocol/libraries/configuration/ReserveConfiguration.sol";
import {IPool} from "aave-v3-core/contracts/interfaces/IPool.sol";
import {ConfiguratorInputTypes} from "aave-v3-core/contracts/protocol/libraries/types/ConfiguratorInputTypes.sol";
import {IDefaultInterestRateStrategy} from "aave-v3-core/contracts/interfaces/IDefaultInterestRateStrategy.sol";
import {IACLManager} from "aave-v3-core/contracts/interfaces/IACLManager.sol";
import {IERC20} from "solidity-utils/contracts/oz-common/interfaces/IERC20.sol";
import {
    UiPoolDataProviderV3,
    IUiPoolDataProviderV3,
    IPoolAddressesProvider
} from "aave-v3-periphery/misc/UiPoolDataProviderV3.sol";
import {IEACAggregatorProxy} from "aave-v3-periphery/misc/interfaces/IEACAggregatorProxy.sol";
import {IDeployConfigTypes} from "src/deployments/interfaces/IDeployConfigTypes.sol";
import {IERC20Metadata} from "src/contracts/dependencies/openzeppelin/interfaces/IERC20Metadata.sol";
import {stdJson} from "forge-std/StdJson.sol";
import {ScriptTools} from "dss-test/ScriptTools.sol";
import {Vm} from "forge-std/Vm.sol";
import "forge-std/console.sol";
import {ReserveInitializer} from "src/periphery/contracts/misc/ReserveInitializer.sol";
import {WHYPE} from "src/tokens/WHYPE.sol";

contract HyperMocknetReservesConfigs {
    using stdJson for string;
    using ReserveConfiguration for DataTypes.ReserveConfigurationMap;

    IDeployConfigTypes.HypurrDeployRegistry deployRegistry;

    Vm internal constant vm2 = Vm(address(bytes20(uint160(uint256(keccak256("hevm cheat code"))))));

    function _fetchMocknetTokens(string memory config)
        internal
        returns (address[] memory tokens)
    {
        console.log("sender", msg.sender);

        tokens = new address[](2);

        tokens[0] = address(config.readAddress(".nativeToken")); // WHYPE
        tokens[1] = address(0x5FbDB2315678afecb367f032d93F642f64180aa3); // USDC

        return tokens;
    }

    function _fetchMocknetOracles(string memory config) internal returns (address[] memory oracles) {
        oracles = new address[](2);

        oracles[0] = address(config.readAddress(".nativeTokenOracle")); // WHYPE
        oracles[1] = address(0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512); // USDC

        return oracles;
    }

    function _updateDebtToken(ConfiguratorInputTypes.UpdateDebtTokenInput memory input) internal {
        _getPoolConfigurator().updateVariableDebtToken(input);
    }

    function _updateAToken(ConfiguratorInputTypes.UpdateATokenInput memory input) internal {
        _getPoolConfigurator().updateAToken(input);
    }

    function _concatName(string memory tokenName) internal pure returns (string memory) {
        return string(abi.encodePacked(tokenName, " Hypurr"));
    }

    function _initReserves(address[] memory tokens, string memory deployedContracts, address deployer) internal {
        ConfiguratorInputTypes.InitReserveInput[] memory inputs =
            new ConfiguratorInputTypes.InitReserveInput[](tokens.length);

        for (uint256 i; i < tokens.length;) {
            IERC20Metadata token = IERC20Metadata(tokens[i]);

            inputs[i] = ConfiguratorInputTypes.InitReserveInput({
                aTokenImpl: deployRegistry.hyTokenImpl, // Address of the aToken implementation
                stableDebtTokenImpl: deployRegistry.disabledStableDebtTokenImpl, // Disabled - not using stable debt in this implementation
                variableDebtTokenImpl: deployRegistry.variableDebtTokenImpl, // Address of the variable debt token implementation
                underlyingAssetDecimals: token.decimals(),
                interestRateStrategyAddress: deployRegistry.defaultInterestRateStrategy, // Address of the interest rate strategy
                underlyingAsset: address(token), // Address of the underlying asset
                treasury: deployRegistry.treasury, // Address of the treasury
                incentivesController: deployRegistry.incentives, // Address of the incentives controller
                aTokenName: string(abi.encodePacked(token.symbol(), " Hypurr")),
                aTokenSymbol: string(abi.encodePacked("hy", token.symbol())),
                variableDebtTokenName: string(abi.encodePacked(token.symbol(), " Variable Debt Hypurr")),
                variableDebtTokenSymbol: string(abi.encodePacked("variableDebt", token.symbol())),
                stableDebtTokenName: "", // Empty as stable debt is disabled
                stableDebtTokenSymbol: "", // Empty as stable debt is disabled
                params: bytes("") // Additional parameters for initialization
            });

            unchecked {
                i++;
            }
        }

        ReserveInitializer initializer = new ReserveInitializer(deployRegistry.wrappedHypeGateway, deployRegistry.poolConfigurator, deployRegistry.pool);

        address payable whype = payable(deployedContracts.readAddress(".whype"));
        address usdc = deployedContracts.readAddress(".usdc");

        WHYPE(whype).deposit{value: 0.1e18}();
        MintableLimitERC20(usdc).mint(address(deployer), 0.1e6);

        uint256[] memory amounts = new uint256[](tokens.length);
        amounts[0] = 0.1e18;
        amounts[1] = 0.1e6;
        for (uint256 i; i < tokens.length;) {
            IERC20(tokens[i]).transfer(address(initializer), amounts[i]);
            unchecked {
                i++;
            }
        }

        _addPoolAdmin(address(initializer));
        
        initializer.batchInitReserves(inputs, amounts);

        _removePoolAdmin(address(initializer));
    }

    function _disableStableDebt(address[] memory tokens) internal {
        for (uint256 i; i < tokens.length;) {
            // Disable stable borrowing
            _getPoolConfigurator().setReserveStableRateBorrowing(tokens[i], false);
            unchecked {
                i++;
            }
        }
    }

    function _enableFlashloans(address[] memory tokens) internal {
        for (uint256 i; i < tokens.length;) {
            _getPoolConfigurator().setReserveFlashLoaning(tokens[i], true);
            unchecked {
                i++;
            }
        }
    }

    function _enableCollateral(address[] memory tokens) internal {
        for (uint256 i; i < tokens.length;) {
            string memory tokenConfig = DeployUtils.readTokenConfig(tokens[i]);
            _getPoolConfigurator().configureReserveAsCollateral(
                tokens[i],
                tokenConfig.readUint(".ltv"),
                tokenConfig.readUint(".liquidationThreshold"),
                tokenConfig.readUint(".liquidationBonus")
            );
            unchecked {
                i++;
            }
        }
    }

    function _enableBorrowing(address[] memory tokens) internal {
        for (uint256 i; i < tokens.length;) {
            _getPoolConfigurator().setReserveBorrowing(tokens[i], true);
            unchecked {
                i++;
            }
        }
    }

    
    function _faucetTokens(address[] memory tokens, uint256[] memory amounts, address[] memory recipients, bool transferTokens) internal {
        // First mint all tokens
        for (uint256 j; j < tokens.length;) {
            uint256 mintLimit = MintableLimitERC20(tokens[j]).mintLimit();
            uint256 remainingAmount = amounts[j] * recipients.length; // Total amount needed for all recipients
            
            while (remainingAmount > 0) {
                uint256 currentMintAmount = remainingAmount > mintLimit ? mintLimit : remainingAmount;
                address[] memory tokenArray = new address[](1);
                tokenArray[0] = tokens[j];
                
                new FaucetReceiver(tokenArray, currentMintAmount);
                remainingAmount -= currentMintAmount;
            }
            
            unchecked {
                j++;
            }
        }

        // Then transfer to all recipients
        if (transferTokens) {
            for (uint256 i; i < recipients.length;) {
                for (uint256 j; j < tokens.length;) {
                    MintableLimitERC20(tokens[j]).transfer(recipients[i], amounts[j]);
                    unchecked {
                        j++;
                    }
                }
                unchecked {
                    i++;
                }
            }
        }
    }

    function _supplyPool(address[] memory tokens, uint256[] memory amounts, address[] memory recipients, address deployer) internal {
        for (uint256 i; i < recipients.length;) {
            for (uint256 j; j < tokens.length;) {
                IERC20Metadata token = IERC20Metadata(tokens[j]);
                uint256 currentBalance = token.balanceOf(deployer);
                // check balance
                require(
                    currentBalance >= amounts[j],
                    string(
                        abi.encodePacked(
                            "Insufficient balance for ",
                            token.symbol(),
                            " (",
                            token.name(),
                            "). Amount Required: ",
                            vm2.toString(amounts[j]),
                            ", Current Balance: ",
                            vm2.toString(currentBalance),
                            ", Token Address: ",
                            vm2.toString(tokens[j]),
                            ", Caller: ",
                            vm2.toString(msg.sender),
                            ", Recipient: ",
                            vm2.toString(recipients[i])
                        )
                    )
                );

                // approve token amount
                token.approve(address(_getPoolInstance()), amounts[j]);

                // supply tokens
                _getPoolInstance().supply(tokens[j], amounts[j], recipients[i], 0);

                unchecked {
                    j++;
                }
            }

            unchecked {
                i++;
            }
        }
    }

    function _borrowFromPool(address[] memory tokens, uint256[] memory amounts, address deployer) internal {
        for (uint256 i; i < tokens.length;) {
            _getPoolInstance().borrow(tokens[i], amounts[i], 2, 0, deployer);
            unchecked {
                i++;
            }   
        }
    }

    function _supplyNative(uint256 amount, address onBehalfOf) internal {
        _getWrappedTokenGateway().depositETH{value: amount}(deployRegistry.pool, onBehalfOf, 0);
    }

    function _addPoolAdmin(address newAdmin) internal {
        IACLManager(_getMarketReport().aclManager).addPoolAdmin(newAdmin);
    }

    function _removePoolAdmin(address oldAdmin) internal {
        IACLManager(_getMarketReport().aclManager).removePoolAdmin(oldAdmin);
    }

    function _setupEModeGroup(
        uint8 categoryId,
        string memory label,
        address[] memory tokens,
        address oracle,
        uint16 ltv,
        uint16 liquidationThreshold,
        uint16 liquidationBonus
    ) internal {
        // setup emode category
        _getPoolConfigurator().setEModeCategory(categoryId, ltv, liquidationThreshold, liquidationBonus, oracle, label);

        // enable tokens for emode category
        for (uint256 i; i < tokens.length;) {
            _getPoolConfigurator().setAssetEModeCategory(tokens[i], categoryId);

            unchecked {
                i++;
            }
        }
    }

    

    function _getAaveOracle() internal view returns (IAaveOracle) {
        return IAaveOracle(_getMarketReport().hyFiOracle);
    }

    function _getPoolConfigurator() internal view returns (IPoolConfigurator) {
        return IPoolConfigurator(deployRegistry.poolConfigurator);
    }

    function _getPoolInstance() internal view returns (IPool) {
        return IPool(_getMarketReport().pool);
    }

    function _getWrappedTokenGateway() internal view returns (WrappedTokenGatewayV3) {
        return WrappedTokenGatewayV3(payable(deployRegistry.wrappedHypeGateway));
    }

    function _getMarketReport() internal view returns (IDeployConfigTypes.HypurrDeployRegistry memory) {
        return deployRegistry;
    }

    function _setDeployRegistry(string memory deployedContracts) internal {
        deployRegistry = IDeployConfigTypes.HypurrDeployRegistry({
            hyTokenImpl: deployedContracts.readAddress(".hyTokenImpl"),
            hyFiOracle: deployedContracts.readAddress(".hyFiOracle"),
            aclManager: deployedContracts.readAddress(".aclManager"),
            admin: deployedContracts.readAddress(".admin"),
            defaultInterestRateStrategy: deployedContracts.readAddress(".defaultInterestRateStrategy"),
            deployer: deployedContracts.readAddress(".deployer"),
            emissionManager: deployedContracts.readAddress(".emissionManager"),
            incentives: deployedContracts.readAddress(".incentives"),
            incentivesImpl: deployedContracts.readAddress(".incentivesImpl"),
            pool: deployedContracts.readAddress(".pool"),
            poolAddressesProvider: deployedContracts.readAddress(".poolAddressesProvider"),
            poolAddressesProviderRegistry: deployedContracts.readAddress(".poolAddressesProviderRegistry"),
            poolConfigurator: deployedContracts.readAddress(".poolConfigurator"),
            poolConfiguratorImpl: deployedContracts.readAddress(".poolConfiguratorImpl"),
            poolImpl: deployedContracts.readAddress(".poolImpl"),
            protocolDataProvider: deployedContracts.readAddress(".protocolDataProvider"),
            disabledStableDebtTokenImpl: deployedContracts.readAddress(".disabledStableDebtTokenImpl"),
            treasury: deployedContracts.readAddress(".treasury"),
            treasuryImpl: deployedContracts.readAddress(".treasuryImpl"),
            uiIncentiveDataProvider: deployedContracts.readAddress(".uiIncentiveDataProvider"),
            uiPoolDataProvider: deployedContracts.readAddress(".uiPoolDataProvider"),
            variableDebtTokenImpl: deployedContracts.readAddress(".variableDebtTokenImpl"),
            walletBalanceProvider: deployedContracts.readAddress(".walletBalanceProvider"),
            wrappedHypeGateway: deployedContracts.readAddress(".wrappedHypeGateway")
        });
    }

    function _setMarketReport(IDeployConfigTypes.HypurrDeployRegistry memory newRegistry) internal {
        deployRegistry = newRegistry;
    }

    function _getReservesList() internal view returns (address[] memory) {
        return IUiPoolDataProviderV3(_getMarketReport().uiPoolDataProvider).getReservesList(
            IPoolAddressesProvider(deployRegistry.poolAddressesProvider)
        );
    }

    function _testPoolDataProvider() internal view {
        IUiPoolDataProviderV3(_getMarketReport().uiPoolDataProvider).getReservesData(
            IPoolAddressesProvider(deployRegistry.poolAddressesProvider)
        );
    }
}
