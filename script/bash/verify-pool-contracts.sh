#!/bin/bash

# Set chain ID and verifier details
CHAIN_ID=999
VERIFIER="sourcify"
VERIFIER_URL="https://sourcify.parsec.finance/verify"

# Set deployment addresses
POOL="0xceCcE0EB9DD2Ef7996e01e25DD70e461F918A14b"
POOL_IMPL="0x980BDd9cF1346800F6307E3B2301fFd3ce8C7523"
POOL_CONFIGURATOR="0x532Bb57DE005EdFd12E7d39a3e9BF8E8A8F544af"
POOL_CONFIGURATOR_IMPL="0x7F4b3CfB3d60aD390E813bc745a44B9030510056"
POOL_ADDRESSES_PROVIDER="0xA73ff12D177D8F1Ec938c3ba0e87D33524dD5594"
POOL_ADDRESSES_PROVIDER_IMPL="0x578ED836E04f7447559b1C7d4B10082C9e1D98c0"

echo "Starting Pool and PoolConfigurator verification..."

# Pool - requires IPoolAddressesProvider as constructor argument
forge verify-contract $POOL lib/aave-v3-core/contracts/protocol/pool/Pool.sol:Pool \
    --constructor-args $(cast abi-encode "constructor(address)" $POOL_ADDRESSES_PROVIDER) \
    --chain-id $CHAIN_ID \
    --verifier $VERIFIER \
    --verifier-url $VERIFIER_URL

# Pool Configurator - requires IPoolAddressesProvider as constructor argument
forge verify-contract $POOL_CONFIGURATOR lib/aave-v3-core/contracts/protocol/pool/PoolConfigurator.sol:PoolConfigurator \
    --constructor-args $(cast abi-encode "constructor(address)" $POOL_ADDRESSES_PROVIDER) \
    --chain-id $CHAIN_ID \
    --verifier $VERIFIER \
    --verifier-url $VERIFIER_URL

echo "Pool and PoolConfigurator verification completed!" 