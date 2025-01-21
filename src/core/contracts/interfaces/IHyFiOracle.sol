// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import {IAaveOracle} from "@aave/core-v3/contracts/interfaces/IAaveOracle.sol";

/**
 * @title IHyFiOracle
 * @author HypurrFi
 * @notice Defines the basic interface for the HypurrFi Oracle
 * @dev Inherits from Aave's oracle interface
 */
interface IHyFiOracle is IAaveOracle {}
