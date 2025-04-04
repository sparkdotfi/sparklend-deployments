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
import {AggregatorV3Interface} from "src/contracts/oracle/interfaces/AggregatorV3Interface.sol";

contract HyperMainnetReservesConfigs {
    using stdJson for string;
    using ReserveConfiguration for DataTypes.ReserveConfigurationMap;

    IDeployConfigTypes.HypurrDeployRegistry deployRegistry;

    Vm internal constant vm2 = Vm(address(bytes20(uint160(uint256(keccak256("hevm cheat code"))))));

    function _fetchMainnetTokens(string memory)
        internal view
        returns (address[] memory tokens)
    {
        console.log("sender", msg.sender);

        tokens = new address[](1);

        // tokens[0] = address(config.readAddress(".nativeToken")); // WHYPE
        // tokens[1] = address(0x0000000000000000000000000000000000000000); // USDC
        // tokens[0] = address(0x94e8396e0869c9F2200760aF0621aFd240E1CF38); // wstHYPE
        tokens[0] = address(0); // UETH

        return tokens;
    }

    function _fetchTokens(string memory config) 
    internal
    returns (address[] memory tokens) {
        string[] memory tokenNames = config.readStringArray(".tokens");
        tokens = new address[](tokenNames.length);
        for (uint i; i < tokenNames.length; i++) {
            string memory tokenConfig = DeployUtils.readTokenConfig(tokenNames[i]);
            tokens[i] = tokenConfig.readAddress(".tokenAddress");

            // SAFEGUARD: verify token symbol matches onchain
            string memory symbol = IERC20Metadata(tokens[i]).symbol();
            require(keccak256(abi.encodePacked(symbol)) == keccak256(abi.encodePacked(tokenNames[i])), 
                string(abi.encodePacked("Token symbol mismatch: ", symbol, " != ", tokenNames[i])));

            // SAFEGUARD: verify token name matches onchain
            string memory name = IERC20Metadata(tokens[i]).name();
            require(keccak256(abi.encodePacked(name)) == keccak256(abi.encodePacked(tokenConfig.readString(".tokenName"))),
                string(abi.encodePacked("Token name mismatch: ", name, " != ", tokenConfig.readString(".tokenName"))));
        }
        return tokens;
    }

    function _fetchMainnetOracles(string memory) internal pure returns (address[] memory oracles) {
        oracles = new address[](1);

        // oracles[0] = address(config.readAddress(".nativeTokenOracle")); // WHYPE
        // oracles[1] = address(0x0000000000000000000000000000000000000000); // USDC
        // oracles[0] = address(0xfD5c563391CDA3B290394da1D6c6a36A3cbf401D); // UBTC
        oracles[0] = address(0x44Bbb85E5B1799569dD02054Cfb38028656Ae30A); // UETH

        return oracles;
    }

    function _fetchOracles(string memory config)
    internal                 
    returns (address[] memory oracles) {
        string[] memory tokenNames = config.readStringArray(".tokens");
        oracles = new address[](tokenNames.length);
        for (uint i; i < tokenNames.length; i++) {
            string memory tokenConfig = DeployUtils.readTokenConfig(tokenNames[i]);
            oracles[i] = tokenConfig.readAddress(".oracleAddress");

            // SAFEGUARD: verify oracle address is valid
            require(IEACAggregatorProxy(oracles[i]).latestAnswer() > 0, string(abi.encodePacked("Oracle price mismatch for ", tokenNames[i])));
            require(IEACAggregatorProxy(oracles[i]).decimals() == 8, string(abi.encodePacked("Oracle decimals mismatch for ", tokenNames[i])));
        
            // SAFEGUARD: verify oracle price is within tolerance of expected price
            int256 oraclePrice = IEACAggregatorProxy(oracles[i]).latestAnswer();
            int256 expectedPrice = int256(tokenConfig.readUint(".expectedPrice"));
            int256 tolerance = (expectedPrice * int256(config.readUint(".oracleTolerancePercentage"))) / 100;

            // SAFEGUARD: verify oracle description matches
            require(
                keccak256(bytes(AggregatorV3Interface(oracles[i]).description())) == 
                keccak256(abi.encodePacked(tokenNames[i], "/USD Oracle")), 
                string(abi.encodePacked("Oracle description mismatch for ", tokenNames[i]))
            );
            
            require(
                oraclePrice >= expectedPrice - tolerance && 
                oraclePrice <= expectedPrice + tolerance,
                string(abi.encodePacked(
                    "Oracle price out of tolerance for ", 
                    tokenNames[i],
                    ": expected ",
                    vm2.toString(uint256(expectedPrice)),
                    " got ",
                    vm2.toString(uint256(oraclePrice))
                ))
            );
        }   
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

    function _initReserves(address[] memory tokens) internal {
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

        uint256[] memory amounts = new uint256[](tokens.length);
        for (uint256 i; i < tokens.length;) {
            amounts[i] = 0.1e18;
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

    function _supplyPool(address[] memory tokens, uint256[] memory amounts, address[] memory recipients) internal {
        for (uint256 i; i < recipients.length;) {
            for (uint256 j; j < tokens.length;) {
                IERC20Metadata token = IERC20Metadata(tokens[j]);
                uint256 currentBalance = token.balanceOf(msg.sender);
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
        address[] memory collateralTokens,
        address[] memory borrowTokens,
        address oracle,
        uint16 ltv,
        uint16 liquidationThreshold,
        uint16 liquidationBonus
    ) internal {
        // setup emode category
        _getPoolConfigurator().setEModeCategory(categoryId, ltv, liquidationThreshold, liquidationBonus, oracle, label);

        // enable tokens for emode category
        for (uint256 i; i < collateralTokens.length;) {
            _getPoolConfigurator().setAssetEModeCategory(collateralTokens[i], categoryId);

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
