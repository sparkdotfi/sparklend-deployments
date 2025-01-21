// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import { IAaveIncentivesController } from "@aave/core-v3/contracts/interfaces/IAaveIncentivesController.sol";

/**
 * @title IHyFiIncentivesController
 * @author HypurrFi
 * @notice Defines the basic interface for a HypurrFi Incentives Controller
 * @dev Inherits from Aave's incentives controller interface
 */
interface IHyFiIncentivesController is IAaveIncentivesController {
}