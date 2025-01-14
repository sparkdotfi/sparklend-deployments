// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import {MockAggregator} from 'aave-v3-core/contracts/mocks/oracle/CLAggregators/MockAggregator.sol';
import {MintableLimitERC20} from 'src/testnet/MintableLimitERC20.sol';
import {IAaveOracle} from 'aave-v3-core/contracts/interfaces/IAaveOracle.sol';
import {IPoolConfigurator} from 'aave-v3-core/contracts/interfaces/IPoolConfigurator.sol';
import {IPool} from 'aave-v3-core/contracts/interfaces/IPool.sol';
import {ConfiguratorInputTypes} from 'aave-v3-core/contracts/protocol/libraries/types/ConfiguratorInputTypes.sol';
import {IDefaultInterestRateStrategy} from 'aave-v3-core/contracts/interfaces/IDefaultInterestRateStrategy.sol';
import {IACLManager} from 'aave-v3-core/contracts/interfaces/IACLManager.sol';
import {UiPoolDataProviderV3, IUiPoolDataProviderV3,IPoolAddressesProvider} from 'aave-v3-periphery/misc/UiPoolDataProviderV3.sol';
import {IEACAggregatorProxy} from 'aave-v3-periphery/misc/interfaces/IEACAggregatorProxy.sol';
import {IDeployConfigTypes} from 'src/deployments/interfaces/IDeployConfigTypes.sol';
import {IERC20Metadata} from "src/contracts/dependencies/openzeppelin/interfaces/IERC20Metadata.sol";
import {stdJson} from "forge-std/StdJson.sol";
import {ScriptTools} from "dss-test/ScriptTools.sol";
import { DeployUtils } from "src/deployments/utils/DeployUtils.sol";
import 'forge-std/console.sol';

contract HyperTestnetReservesConfigs {

  using stdJson for string;

  IDeployConfigTypes.HypurrDeployRegistry deployRegistry;

  function _deployTestnetTokens(
    string memory config
  )
    internal
    returns (
        address[] memory tokens,
        address[] memory oracles
    )
  { 
    console.log('Aave V3 Batch Deployment');
    console.log('sender', msg.sender);

    tokens  = new address[](4);

    tokens[0] = address(config.readAddress('.nativeToken')); // config.wrappedNativeToken
    tokens[1] = address(new MintableLimitERC20('USD Coin', 'USDC', 6, 1000e6));
    tokens[2] = address(new MintableLimitERC20('Staked USDe', 'sUSDe', 18, 1000e18));
    // tokens[3] = address(0xe2fbc9cb335a65201fcde55323ae0f4e8a96a616); // stHYPE
    tokens[3] = address(new MintableLimitERC20('Solv BTC', 'SolvBTC', 18, 0.1e18));

    oracles = new address[](1);

    // oracles[0] = address(config.networkBaseTokenPriceInUsdProxyAggregator); //config.networkBaseTokenPriceInUsdProxyAggregator
    // oracles[1] = address(new MockAggregator(1e8));
    // oracles[2] = address(new MockAggregator(100_000e8));
    oracles[0] = address(new MockAggregator(100_000e8));

    return (tokens, oracles);
  }

  function _fetchStableTokens()
    internal
    returns (
        address[] memory tokens
    )
  { 
    tokens  = new address[](2);
    
    // tokens[0] = address(0x8bf86549d308e50Db889cF843AEBd6b7B0d7BB9a); // WHYPE
    tokens[0] = address(0x6fDbAF3102eFC67ceE53EeFA4197BE36c8E1A094); // USDC
    tokens[1] = address(0x2222C34A8dd4Ea29743bf8eC4fF165E059839782); // sUSDe

    return tokens;
  }

  function _fetchTestnetTokens()
    internal
    returns (
        address[] memory tokens
    )
  { 
    tokens  = new address[](5);

    tokens[0] = address(0x4B85aCF84b2593D67f6593D18504dBb3A337D3D8); // SolvBTC
    tokens[1] = address(0x8bf86549d308e50Db889cF843AEBd6b7B0d7BB9a); // WHYPE
    tokens[2] = address(0xe2FbC9cB335A65201FcDE55323aE0F4E8A96A616); // stHYPE (stTESTH on testnet)
    tokens[3] = address(0x6fDbAF3102eFC67ceE53EeFA4197BE36c8E1A094); // USDC
    tokens[4] = address(0x2222C34A8dd4Ea29743bf8eC4fF165E059839782); // sUSDe

    //0x9edA7E43821EedFb677A69066529F16DB3A2dD73 USDXL

    return tokens;
  }

  function _fetchTestnetOracles()
    internal
    returns (
        address[] memory oracles
    )
  { 
    oracles  = new address[](5);

    oracles[0] = address(0x85C4F855Bc0609D2584405819EdAEa3aDAbfE97D); // SolvBTC
    oracles[1] = address(0xC3346631E0A9720582fB9CAbdBEA22BC2F57741b); // WHYPE
    oracles[2] = address(0xC3346631E0A9720582fB9CAbdBEA22BC2F57741b); // stHYPE (stTESTH on testnet); using redstone HYPE oracle on testnet
    oracles[3] = address(0xa0f2EF6ceC437a4e5F6127d6C51E1B0d3A746911); // USDC
    oracles[4] = address(0xa0f2EF6ceC437a4e5F6127d6C51E1B0d3A746911); // sUSDe

    // USDXL uses a static oracle price of 1e8

    return oracles;
  }

  function _faucetTokens(
    address[] memory tokens,
    uint256[] memory amounts,
    address[] memory recipients
  ) 
    internal
  {
    for (uint i; i < recipients.length; ){
      for (uint j; j < tokens.length; ){
        MintableLimitERC20(tokens[j]).mint(amounts[j]);
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

  function _updateDebtToken(
    ConfiguratorInputTypes.UpdateDebtTokenInput memory input
  )
    internal
  {
    _getPoolConfigurator().updateVariableDebtToken(input);
  }

  function _updateAToken(
    ConfiguratorInputTypes.UpdateATokenInput memory input
  )
    internal
  {
    _getPoolConfigurator().updateAToken(input);
  }

  function _concatName(string memory tokenName) internal pure returns (string memory) {
    return string(abi.encodePacked(tokenName, " Hypurr"));
  }

  function _initReserves(
    address[] memory tokens
  ) 
    internal
  {
    ConfiguratorInputTypes.InitReserveInput[] memory inputs = new ConfiguratorInputTypes.InitReserveInput[](tokens.length);

    for (uint i; i < tokens.length; ) {
      IERC20Metadata token = IERC20Metadata(tokens[i]);

      inputs[i] = ConfiguratorInputTypes.InitReserveInput({
        aTokenImpl: deployRegistry.aTokenImpl, // Address of the aToken implementation
        stableDebtTokenImpl: deployRegistry.stableDebtTokenImpl, // Address of the stable debt token implementation
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
        stableDebtTokenName: string(abi.encodePacked(token.symbol(), " Stable Debt Hypurr")),
        stableDebtTokenSymbol: string(abi.encodePacked("stableDebt", token.symbol())),
        params: bytes('') // Additional parameters for initialization
      });

      unchecked { i++; }
    }
    
    // set reserves configs
    _getPoolConfigurator().initReserves(inputs);
  }

  function _enableCollateral(
    address[] memory tokens
  )
    internal
  {
    for (uint i; i < tokens.length; ) {
      string memory tokenConfig = DeployUtils.readTokenConfig(tokens[i]);
      _getPoolConfigurator().configureReserveAsCollateral(
        tokens[i],
        tokenConfig.readUint('.ltv'), // LTV (80%)
        tokenConfig.readUint('.liquidationThreshold'), // Liq. threshold (90%)
        tokenConfig.readUint('.liquidationBonus') // Liq. bonus (5% tax)
      );
      unchecked { i++; }
    }
  }

  function _enableBorrowing(
    address[] memory tokens
  )
    internal
  {
    for (uint i; i < tokens.length; ) {
      _getPoolConfigurator().setReserveBorrowing(tokens[i], true);
      unchecked { i++; }
    }
  }

  function _supplyPool(
    address[] memory tokens,
    uint256[] memory amounts,
    address onBehalfOf
  ) internal {
    for (uint i; i < tokens.length; ){
      // approve token amount
      MintableLimitERC20(tokens[i]).approve(address(_getPoolInstance()), amounts[i]);
      
      // supply tokens
      _getPoolInstance().supply(
        tokens[i],
        amounts[i],
        onBehalfOf,
        0
      );

      unchecked {
        i++;
      }
    }
  }

  function _addPoolAdmin(
    address newAdmin
  )
    internal
  {
    IACLManager(_getMarketReport().aclManager).addPoolAdmin(newAdmin);
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
  )
    internal
  {
    // setup emode category
    _getPoolConfigurator().setEModeCategory(
      categoryId,
      ltv,
      liquidationThreshold,
      liquidationBonus,
      oracle,
      label
    );

    // enable tokens for emode category
    for (uint i; i < collateralTokens.length; ){
      _getPoolConfigurator().setAssetEModeCategory(collateralTokens[i], categoryId);

      unchecked {
        i++;
      }
    }
  }

  function _deployUiPoolDataProvider()
    internal
  {
    IDeployConfigTypes.HypurrDeployRegistry memory deployRegistry = _getMarketReport();
    deployRegistry.uiPoolDataProvider = address(new UiPoolDataProviderV3(
      IEACAggregatorProxy(0xC3346631E0A9720582fB9CAbdBEA22BC2F57741b),
      IEACAggregatorProxy(UiPoolDataProviderV3(deployRegistry.uiPoolDataProvider).marketReferenceCurrencyPriceInUsdProxyAggregator())
    ));
    _setMarketReport(deployRegistry);
  }

  function _getAaveOracle()
    internal
    view
    returns (
      IAaveOracle
    )
  {
    return IAaveOracle(_getMarketReport().aaveOracle);
  }

  function _getPoolConfigurator()
    internal
    view
    returns (
      IPoolConfigurator
    )
  {
    return IPoolConfigurator(deployRegistry.poolConfigurator);
  }

  function _getPoolInstance()
    internal
    view
    returns (
      IPool
    )
  {
    return IPool(_getMarketReport().pool);
  }

  function _getMarketReport()
    internal
    view
    returns (
      IDeployConfigTypes.HypurrDeployRegistry memory
    ) {
      return deployRegistry;
  }

  function _setDeployRegistry(string memory deployedContracts)
    internal
  {
    deployRegistry = IDeployConfigTypes.HypurrDeployRegistry({
      aTokenImpl: deployedContracts.readAddress(".aTokenImpl"),
      aaveOracle: deployedContracts.readAddress(".aaveOracle"),
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
      stableDebtTokenImpl: deployedContracts.readAddress(".stableDebtTokenImpl"),
      treasury: deployedContracts.readAddress(".treasury"),
      treasuryImpl: deployedContracts.readAddress(".treasuryImpl"),
      uiIncentiveDataProvider: deployedContracts.readAddress(".uiIncentiveDataProvider"),
      uiPoolDataProvider: deployedContracts.readAddress(".uiPoolDataProvider"),
      variableDebtTokenImpl: deployedContracts.readAddress(".variableDebtTokenImpl"),
      walletBalanceProvider: deployedContracts.readAddress(".walletBalanceProvider"),
      wrappedTokenGateway: deployedContracts.readAddress(".wrappedTokenGateway")
    });
  }

  function _setMarketReport(IDeployConfigTypes.HypurrDeployRegistry memory newRegistry)
    internal
  {
      deployRegistry = newRegistry;
  }

  function _getReservesList()
    internal
    view
    returns (
      address[] memory
    )
    {
      return IUiPoolDataProviderV3(
        _getMarketReport().uiPoolDataProvider
      ).getReservesList(
        IPoolAddressesProvider(deployRegistry.poolAddressesProvider)
      );
    }
}
