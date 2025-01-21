// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {AaveV3ConfigEngine} from "aave-helpers/v3-config-engine/AaveV3ConfigEngine.sol";
import {IPoolAddressesProvider} from "@aave/core-v3/contracts/interfaces/IPoolAddressesProvider.sol";
import {IPool} from "@aave/core-v3/contracts/interfaces/IPool.sol";
import {IPoolConfigurator} from "@aave/core-v3/contracts/interfaces/IPoolConfigurator.sol";
import {IAaveOracle} from "@aave/core-v3/contracts/interfaces/IAaveOracle.sol";
import {IACLManager} from "@aave/core-v3/contracts/interfaces/IACLManager.sol";
import {IV3RateStrategyFactory} from "aave-helpers/v3-config-engine/IV3RateStrategyFactory.sol";

/**
 * @title HyFiConfigEngine
 * @author HypurrFi
 * @notice Configuration engine for HypurrFi protocol parameters
 * @dev Inherits from Aave's V3 configuration engine
 */
contract HyFiConfigEngine is AaveV3ConfigEngine {
    /**
     * @dev Constructor
     * @param pool The address of the Pool contract
     * @param configurator The address of the PoolConfigurator contract
     * @param oracle The address of the Oracle contract
     * @param aTokenImpl The address of the ATokeimplementation
     * @param vTokenImpl The address of the VToken implementation
     * @param sTokenImpl The address of the SToken implementation
     * @param rewardsController The address of the RewardsController contract
     * @param collector The address of the Collector contract
     * @param rateStrategiesFactory The address of the RateStrategyFactory contract
     */
    constructor(
        IPool pool,
        IPoolConfigurator configurator,
        IAaveOracle oracle,
        address aTokenImpl,
        address vTokenImpl,
        address sTokenImpl,
        address rewardsController,
        address collector,
        IV3RateStrategyFactory rateStrategiesFactory
    )
        AaveV3ConfigEngine(
            pool,
            configurator,
            oracle,
            aTokenImpl,
            vTokenImpl,
            sTokenImpl,
            rewardsController,
            collector,
            rateStrategiesFactory
        )
    {}
}
