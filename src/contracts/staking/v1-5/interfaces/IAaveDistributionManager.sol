// SPDX-License-Identifier: agpl-3.0
pragma solidity ^0.8.0;

import {DistributionTypes} from '../lib/DistributionTypes.sol';

interface IAaveDistributionManager {
  function configureAssets(
    DistributionTypes.AssetConfigInput[] memory assetsConfigInput
  ) external;
}