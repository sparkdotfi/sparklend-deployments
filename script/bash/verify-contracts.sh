#!/bin/bash

# Set chain ID and verifier details
CHAIN_ID=999
VERIFIER="sourcify"
VERIFIER_URL="https://sourcify.parsec.finance/verify"

# Set deployment addresses from JSON
ACL_MANAGER="0x79CBF4832439554885E4bec9457C1427DFB9D0d3"
DEFAULT_INTEREST_RATE_STRATEGY="0x701B26833A2dFa145B29Ef1264DE3a5240E17bBD"
STABLE_DEBT_TOKEN="0x2d9C9f80e4DA27d30835aBd82c334f074E209eDa"
HYFI_ORACLE="0x9BE2ac1ff80950DCeb816842834930887249d9A8"
HYTOKEN_IMPL="0xa3703e1a77A23A92F21cd5565e5955E98a4fAAcC"
POOL="0xceCcE0EB9DD2Ef7996e01e25DD70e461F918A14b"
POOL_ADDRESSES_PROVIDER="0xA73ff12D177D8F1Ec938c3ba0e87D33524dD5594"
POOL_ADDRESSES_PROVIDER_REGISTRY="0x578ED836E04f7447559b1C7d4B10082C9e1D98c0"
POOL_CONFIGURATOR="0x532Bb57DE005EdFd12E7d39a3e9BF8E8A8F544af"
POOL_CONFIGURATOR_IMPL="0x7F4b3CfB3d60aD390E813bc745a44B9030510056"
POOL_IMPL="0x980BDd9cF1346800F6307E3B2301fFd3ce8C7523"
PROTOCOL_DATA_PROVIDER="0x895C799a5bbdCb63B80bEE5BD94E7b9138D977d6"
RESERVE_INITIALIZER="0xafE1b6f29217fc917E3f9C725De07fDf4506f786"
TREASURY="0xdC6E5b7aA6fCbDECC1Fda2b1E337ED8569730288"
TREASURY_CONTROLLER="0x9E6eFa77192DA81E22c8791Ba65c5A5E9795E697"
TREASURY_IMPL="0x2f268cF4730f17D00f7f2ce7f3B97cFE5845D862"
UI_INCENTIVE_DATA_PROVIDER="0x8ebA6fc4Ff6Ba4F12512DD56d0E4aaC6081f5274"
UI_POOL_DATA_PROVIDER="0x7b883191011AEAe40581d3Fa1B112413808C9c00"
VARIABLE_DEBT_TOKEN="0xdBcF99e5202b2bB9C47182209c7a551524f7c690"
WALLET_BALANCE_PROVIDER="0xE913De89D8c868aEF96D3b10dAAE1900273D7Bb2"
WRAPPED_HYPE_GATEWAY="0xd1EF87FeFA83154F83541b68BD09185e15463972"
WST_HYPE_ORACLE="0x5777a35eed45cfd605dad5d3d7b531ac2f409cd1"

echo "Starting contract verification..."

# WstHypeOracle
forge verify-contract $WST_HYPE_ORACLE src/periphery/contracts/misc/WstHypeOracle.sol:WstHypeOracle \
    --chain-id $CHAIN_ID \
    --verifier $VERIFIER \
    --verifier-url $VERIFIER_URL

# ACL Manager
forge verify-contract $ACL_MANAGER lib/aave-v3-core/contracts/protocol/configuration/ACLManager.sol:ACLManager \
    --chain-id $CHAIN_ID \
    --verifier $VERIFIER \
    --verifier-url $VERIFIER_URL

# Default Interest Rate Strategy
forge verify-contract $DEFAULT_INTEREST_RATE_STRATEGY lib/aave-v3-core/contracts/protocol/pool/DefaultReserveInterestRateStrategy.sol:DefaultReserveInterestRateStrategy \
    --chain-id $CHAIN_ID \
    --verifier $VERIFIER \
    --verifier-url $VERIFIER_URL

# HyFi Oracle
forge verify-contract $HYFI_ORACLE src/core/contracts/misc/HyFiOracle.sol:HyFiOracle \
    --chain-id $CHAIN_ID \
    --verifier $VERIFIER \
    --verifier-url $VERIFIER_URL

# HyToken Implementation
forge verify-contract $HYTOKEN_IMPL src/core/contracts/protocol/tokenization/HyToken.sol:HyToken \
    --chain-id $CHAIN_ID \
    --verifier $VERIFIER \
    --verifier-url $VERIFIER_URL

# Pool
forge verify-contract $POOL lib/aave-v3-core/contracts/protocol/libraries/aave-upgradeability/InitializableImmutableAdminUpgradeabilityProxy.sol:InitializableImmutableAdminUpgradeabilityProxy \
    --chain-id $CHAIN_ID \
    --verifier $VERIFIER \
    --verifier-url $VERIFIER_URL

# Pool Addresses Provider
forge verify-contract $POOL_ADDRESSES_PROVIDER lib/aave-v3-core/contracts/protocol/configuration/PoolAddressesProvider.sol:PoolAddressesProvider \
    --chain-id $CHAIN_ID \
    --verifier $VERIFIER \
    --verifier-url $VERIFIER_URL

# Pool Addresses Provider Registry
forge verify-contract $POOL_ADDRESSES_PROVIDER_REGISTRY lib/aave-v3-core/contracts/protocol/configuration/PoolAddressesProviderRegistry.sol:PoolAddressesProviderRegistry \
    --chain-id $CHAIN_ID \
    --verifier $VERIFIER \
    --verifier-url $VERIFIER_URL

# Pool Configurator
forge verify-contract $POOL_CONFIGURATOR lib/aave-v3-core/contracts/protocol/libraries/aave-upgradeability/InitializableImmutableAdminUpgradeabilityProxy.sol:InitializableImmutableAdminUpgradeabilityProxy \
    --chain-id $CHAIN_ID \
    --verifier $VERIFIER \
    --verifier-url $VERIFIER_URL

# Protocol Data Provider
forge verify-contract $PROTOCOL_DATA_PROVIDER src/core/contracts/misc/HyFiProtocolDataProvider.sol:HyFiProtocolDataProvider \
    --chain-id $CHAIN_ID \
    --verifier $VERIFIER \
    --verifier-url $VERIFIER_URL

# Treasury
forge verify-contract $TREASURY lib/aave-v3-core/contracts/dependencies/openzeppelin/upgradeability/InitializableAdminUpgradeabilityProxy.sol:InitializableAdminUpgradeabilityProxy \
    --chain-id $CHAIN_ID \
    --verifier $VERIFIER \
    --verifier-url $VERIFIER_URL

# Treasury Controller
forge verify-contract $TREASURY_CONTROLLER lib/aave-v3-periphery/contracts/treasury/CollectorController.sol:CollectorController \
    --chain-id $CHAIN_ID \
    --verifier $VERIFIER \
    --verifier-url $VERIFIER_URL

forge verify-contract $TREASURY_IMPL lib/aave-v3-periphery/contracts/treasury/Collector.sol:Collector \
    --chain-id $CHAIN_ID \
    --verifier $VERIFIER \
    --verifier-url $VERIFIER_URL

# Variable Debt Token
forge verify-contract $VARIABLE_DEBT_TOKEN lib/aave-v3-core/contracts/protocol/tokenization/VariableDebtToken.sol:VariableDebtToken \
    --chain-id $CHAIN_ID \
    --verifier $VERIFIER \
    --verifier-url $VERIFIER_URL

# Stable Debt Token
forge verify-contract $STABLE_DEBT_TOKEN src/core/contracts/protocol/tokenization/DisabledStableDebtToken.sol:DisabledStableDebtToken \
    --chain-id $CHAIN_ID \
    --verifier $VERIFIER \
    --verifier-url $VERIFIER_URL

# UI Incentive Data Provider
forge verify-contract $UI_INCENTIVE_DATA_PROVIDER lib/aave-v3-periphery/contracts/misc/UiIncentiveDataProviderV3.sol:UiIncentiveDataProviderV3 \
    --chain-id $CHAIN_ID \
    --verifier $VERIFIER \
    --verifier-url $VERIFIER_URL

# UI Pool Data Provider
forge verify-contract $UI_POOL_DATA_PROVIDER lib/aave-v3-periphery/contracts/misc/UiPoolDataProviderV3.sol:UiPoolDataProviderV3 \
    --chain-id $CHAIN_ID \
    --verifier $VERIFIER \
    --verifier-url $VERIFIER_URL

# Wallet Balance Provider
forge verify-contract $WALLET_BALANCE_PROVIDER lib/aave-v3-periphery/contracts/misc/WalletBalanceProvider.sol:WalletBalanceProvider \
    --chain-id $CHAIN_ID \
    --verifier $VERIFIER \
    --verifier-url $VERIFIER_URL

# Wrapped HYPE Gateway
forge verify-contract $WRAPPED_HYPE_GATEWAY src/periphery/contracts/misc/WrappedHypeGateway.sol:WrappedHypeGateway \
    --chain-id $CHAIN_ID \
    --verifier $VERIFIER \
    --verifier-url $VERIFIER_URL

echo "Contract verification process completed!"