// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.10;

import {SafeERC20} from 'lib/solidity-utils/src/contracts/oz-common/SafeERC20.sol';
import {SafeMath} from '@aave/core-v3/contracts/dependencies/openzeppelin/contracts/SafeMath.sol';
import {PercentageMath} from '@aave/core-v3/contracts/protocol/libraries/math/PercentageMath.sol';
import {IPoolAddressesProvider} from '@aave/core-v3/contracts/interfaces/IPoolAddressesProvider.sol';
import {BaseGluexAdapter} from './BaseGluexAdapter.sol';
import {IERC20} from 'lib/solidity-utils/src/contracts/oz-common/interfaces/IERC20.sol';

/**
 * @title BaseGluexBuyAdapter
 * @notice Implements the logic for buying tokens on Gluex
 */
abstract contract BaseGluexBuyAdapter is BaseGluexAdapter {
  using SafeERC20 for IERC20;

  address public immutable GLUEX_ROUTER;

  constructor(
    IPoolAddressesProvider addressesProvider,
    address gluexRouter
  ) BaseGluexAdapter(addressesProvider) {
    GLUEX_ROUTER = gluexRouter;
  }

  /**
   * @dev Swaps a token for another using Gluex
   * @param gluexData Data for Gluex Router
   * @param sellAsset Asset to be sold
   * @param buyAsset Asset to be bought
   * @return amountSold Amount of sellAsset sold
   * @return amountBought Amount of buyAsset bought
   */
  function _buyOnGluex(
    bytes memory gluexData,
    IERC20 sellAsset,
    IERC20 buyAsset
  ) internal returns (uint256 amountSold, uint256 amountBought) {
    uint256 sellAssetBalanceBefore = sellAsset.balanceOf(address(this));
    uint256 buyAssetBalanceBefore = buyAsset.balanceOf(address(this));

    (bool success, ) = address(GLUEX_ROUTER).call(gluexData);
    if (!success) {
      // Copy revert reason from call
      assembly {
        returndatacopy(0, 0, returndatasize())
        revert(0, returndatasize())
      }
    }

    uint256 sellAssetBalanceAfter = sellAsset.balanceOf(address(this));
    uint256 buyAssetBalanceAfter = buyAsset.balanceOf(address(this));

    amountSold = sellAssetBalanceBefore - sellAssetBalanceAfter;
    amountBought = buyAssetBalanceAfter - buyAssetBalanceBefore;
  }
}