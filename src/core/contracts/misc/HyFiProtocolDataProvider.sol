// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import {AaveProtocolDataProvider} from "@aave/core-v3/contracts/misc/AaveProtocolDataProvider.sol";
import {IPoolAddressesProvider} from "@aave/core-v3/contracts/interfaces/IPoolAddressesProvider.sol";

/**
 * @title HypurrFiProtocolDataProvider
 * @author HypurrFi
 * @notice Peripheral contract to collect and pre-process information from the Pool
 */
contract HyFiProtocolDataProvider is AaveProtocolDataProvider {
    /**
     * @dev Constructor
     * @param addressesProvider The address of the PoolAddressesProvider contract
     */
    constructor(IPoolAddressesProvider addressesProvider) AaveProtocolDataProvider(addressesProvider) {}
}
