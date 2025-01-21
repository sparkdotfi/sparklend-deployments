// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.10;

import {AaveOracle} from "@aave/core-v3/contracts/misc/AaveOracle.sol";
import {IPoolAddressesProvider} from "@aave/core-v3/contracts/interfaces/IPoolAddressesProvider.sol";

/**
 * @title HypurrFiOracle
 * @author HypurrFi
 * @notice Oracle contract for HypurrFi, extending Aave's oracle implementation
 */
contract HyFiOracle is AaveOracle {
    /**
     * @dev Constructor
     * @param provider The address of the PoolAddressesProvider
     * @param assets The addresses of the assets
     * @param sources The address of the source of each asset
     */
    constructor(
        IPoolAddressesProvider provider,
        address[] memory assets,
        address[] memory sources,
        address fallbackOracle,
        address baseCurrency,
        uint256 baseCurrencyUnit
    ) AaveOracle(provider, assets, sources, fallbackOracle, baseCurrency, baseCurrencyUnit) {}
}
