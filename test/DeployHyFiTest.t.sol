// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import {stdJson} from "forge-std/StdJson.sol";
import {ScriptTools} from "dss-test/ScriptTools.sol";
import {DeployUtils} from "src/deployments/utils/DeployUtils.sol";
import {DeployHyFiUtils} from "src/deployments/utils/DeployHyFiUtils.sol";
import {MockAggregator} from "aave-v3-core/contracts/mocks/oracle/CLAggregators/MockAggregator.sol";
import {WHYPE} from "src/tokens/WHYPE.sol";
import {InitializableAdminUpgradeabilityProxy} from
    "aave-v3-core/contracts/dependencies/openzeppelin/upgradeability/InitializableAdminUpgradeabilityProxy.sol";
import {IHyFiIncentivesController} from "src/core/contracts/interfaces/IHyFiIncentivesController.sol";
import {Collector} from "aave-v3-periphery/treasury/Collector.sol";
import {RewardsController} from "aave-v3-periphery/rewards/RewardsController.sol";

contract DeployHyFiTest is Test, DeployHyFiUtils {
    using stdJson for string;

    function setUp() public {
        instanceId = "hypurrfi-localnet";
        vm.setEnv("FOUNDRY_ROOT_CHAINID", vm.toString(block.chainid));

        config = DeployUtils.loadConfig(instanceId);

        // Deploy WHYPE token first
        WHYPE whype = new WHYPE();

        // Deploy mock oracle
        MockAggregator mockOracle = new MockAggregator(25e8);
    
        // Add WHYPE address and mock oracle address to config
        config = string(
            bytes(
                string.concat(
                    '{',
                        '"admin": "', bytes(config.readString(".admin")), '",',
                        '"marketId": "', bytes(config.readString(".marketId")), '",',
                        '"nativeToken": "', bytes(vm.toString(address(whype))), '",',
                        '"nativeTokenOracle": "', bytes(vm.toString(address(mockOracle))), '"',
                    '}'
                )
            )
        );

        admin = config.readAddress(".admin");
        deployer = msg.sender;

        console.log("Caller (msg.sender):", msg.sender);
        console.log("Admin address:", admin);
        console.log("Deployer address:", deployer);

        vm.startPrank(deployer);
        _deployHyFi();
        vm.stopPrank();
    }

    function test_hyFi_deploy_poolAddressesProviderRegistry() public {

        console.log("Testing poolAddressesProviderRegistry");
        address[] memory providersList = registry.getAddressesProvidersList();

        assertEq(registry.owner(), admin);
        assertEq(providersList.length, 1);
        assertEq(providersList[0], address(poolAddressesProvider));

        assertEq(registry.getAddressesProviderAddressById(1), address(poolAddressesProvider));

        assertEq(registry.getAddressesProviderIdByAddress(address(poolAddressesProvider)), 1);
    }

    function test_hyFi_deploy_poolAddressesProvider() public {
        assertEq(poolAddressesProvider.owner(), admin);
        assertEq(poolAddressesProvider.getMarketId(), "HypurrFi Localnet");
        assertEq(poolAddressesProvider.getPool(), address(pool));
        assertEq(poolAddressesProvider.getPoolConfigurator(), address(poolConfigurator));
        assertEq(poolAddressesProvider.getPriceOracle(), address(hyFiOracle));
        assertEq(poolAddressesProvider.getACLManager(), address(aclManager));
        assertEq(poolAddressesProvider.getACLAdmin(), admin);
        assertEq(poolAddressesProvider.getPriceOracleSentinel(), address(0));
        assertEq(poolAddressesProvider.getPoolDataProvider(), address(protocolDataProvider));
    }

    function test_hyFi_deploy_aclManager() public {
        // NOTE: Also verify that no other address than the admin address has any role (verify with events)
        assertEq(address(aclManager.ADDRESSES_PROVIDER()), address(poolAddressesProvider));

        bytes32 defaultAdmin = aclManager.DEFAULT_ADMIN_ROLE();
        bytes32 emergencyAdmin = aclManager.EMERGENCY_ADMIN_ROLE();
        bytes32 poolAdmin = aclManager.POOL_ADMIN_ROLE();

        assertEq(aclManager.getRoleAdmin(poolAdmin), defaultAdmin);
        assertEq(aclManager.getRoleAdmin(emergencyAdmin), defaultAdmin);

        assertTrue(aclManager.hasRole(defaultAdmin, admin));
        assertTrue(!aclManager.hasRole(defaultAdmin, deployer));

        assertTrue(aclManager.hasRole(poolAdmin, admin));
        assertTrue(!aclManager.hasRole(poolAdmin, deployer));

        assertTrue(aclManager.hasRole(emergencyAdmin, admin));

        assertEq(aclManager.getRoleAdmin(aclManager.RISK_ADMIN_ROLE()), defaultAdmin);
        assertEq(aclManager.getRoleAdmin(aclManager.FLASH_BORROWER_ROLE()), defaultAdmin);
        assertEq(aclManager.getRoleAdmin(aclManager.BRIDGE_ROLE()), defaultAdmin);
        assertEq(aclManager.getRoleAdmin(aclManager.ASSET_LISTING_ADMIN_ROLE()), defaultAdmin);
    }

    function test_hyFi_deploy_protocolDataProvider() public {
        assertEq(address(protocolDataProvider.ADDRESSES_PROVIDER()), address(poolAddressesProvider));
    }

    function test_hyFi_deploy_poolConfigurator() public {
        assertEq(poolConfigurator.CONFIGURATOR_REVISION(), 1);
        assertImplementation(address(poolAddressesProvider), address(poolConfigurator), address(poolConfiguratorImpl));
    }

    function test_hyFi_deploy_pool() public {
        assertEq(address(pool.ADDRESSES_PROVIDER()), address(poolAddressesProvider));

        assertEq(pool.POOL_REVISION(), 1);
        assertEq(pool.MAX_STABLE_RATE_BORROW_SIZE_PERCENT(), 0.25e4);
        assertEq(pool.BRIDGE_PROTOCOL_FEE(), 0);
        assertEq(pool.FLASHLOAN_PREMIUM_TOTAL(), 0);
        assertEq(pool.FLASHLOAN_PREMIUM_TO_PROTOCOL(), 0);
        assertEq(pool.MAX_NUMBER_RESERVES(), 128);

        assertImplementation(address(poolAddressesProvider), address(pool), address(poolImpl));

        address[] memory reserves = pool.getReservesList();
        assertEq(reserves.length, 0);
    }

    function test_hyFi_deploy_tokenImpls() public {
        assertEq(address(hyTokenImpl.POOL()), address(pool));
        assertEq(address(variableDebtTokenImpl.POOL()), address(pool));
        assertEq(address(disabledStableDebtTokenImpl.POOL()), address(pool));
    }

    function test_hyFi_deploy_treasury() public {
        assertEq(address(treasuryController.owner()), admin);
        assertEq(treasury.REVISION(), 1);
        assertEq(treasury.getFundsAdmin(), address(treasuryController));

        assertImplementation(admin, address(treasury), address(treasuryImpl));
    }

    function test_hyFi_deploy_incentives() public {
        assertEq(address(emissionManager.owner()), admin);
        assertEq(address(emissionManager.getRewardsController()), address(incentivesProxy));

        // assertEq(incentivesProxy.REVISION(), 1);
        // assertEq(incentivesProxy.EMISSION_MANAGER(), address(emissionManager));

        // assertImplementation(admin, address(incentivesProxy), address(incentivesImpl));
    }

    function test_hyFi_deploy_misc_contracts() public {
        address nativeToken = config.readAddress(".nativeToken");
        address nativeTokenOracle = config.readAddress(".nativeTokenOracle");

        assertEq(address(uiPoolDataProvider.networkBaseTokenPriceInUsdProxyAggregator()), nativeTokenOracle);
        assertEq(address(uiPoolDataProvider.marketReferenceCurrencyPriceInUsdProxyAggregator()), nativeTokenOracle);

        assertEq(wrappedHypeGateway.owner(), admin);
        assertEq(wrappedHypeGateway.getWETHAddress(), nativeToken);
    }

    function test_hyFi_deploy_oracles() public {
        assertEq(address(hyFiOracle.ADDRESSES_PROVIDER()), address(poolAddressesProvider));
        assertEq(hyFiOracle.BASE_CURRENCY(), address(0));
        assertEq(hyFiOracle.BASE_CURRENCY_UNIT(), 10 ** 8);
        assertEq(hyFiOracle.getFallbackOracle(), address(0));
    }

    function test_implementation_contracts_initialized() public {
        vm.expectRevert("Contract instance has already been initialized");
        poolConfiguratorImpl.initialize(poolAddressesProvider);

        vm.expectRevert("Contract instance has already been initialized");
        poolImpl.initialize(poolAddressesProvider);

        vm.expectRevert("Contract instance has already been initialized");
        Collector(treasuryImpl).initialize(address(0));

        vm.expectRevert("Contract instance has already been initialized");
        RewardsController(address(incentivesProxy)).initialize(address(0));

        vm.expectRevert("Contract instance has already been initialized");
        hyTokenImpl.initialize(
            pool, address(0), address(0), IHyFiIncentivesController(address(0)), 0, "SPTOKEN_IMPL", "SPTOKEN_IMPL", ""
        );

        vm.expectRevert("Contract instance has already been initialized");
        disabledStableDebtTokenImpl.initialize(
            pool,
            address(0),
            IHyFiIncentivesController(address(0)),
            0,
            "STABLE_DEBT_TOKEN_IMPL",
            "STABLE_DEBT_TOKEN_IMPL",
            ""
        );

        vm.expectRevert("Contract instance has already been initialized");
        variableDebtTokenImpl.initialize(
            pool,
            address(0),
            IHyFiIncentivesController(address(0)),
            0,
            "VARIABLE_DEBT_TOKEN_IMPL",
            "VARIABLE_DEBT_TOKEN_IMPL",
            ""

        );
    }

    function assertImplementation(address _admin, address proxy, address implementation) internal {
        vm.prank(_admin);
        assertEq(InitializableAdminUpgradeabilityProxy(payable(proxy)).implementation(), implementation);
    }
}
