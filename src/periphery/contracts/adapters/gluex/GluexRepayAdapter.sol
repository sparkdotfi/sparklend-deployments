// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.10;

import {DataTypes} from '@aave/core-v3/contracts/protocol/libraries/types/DataTypes.sol';
import {IERC20WithPermit} from '@aave/core-v3/contracts/interfaces/IERC20WithPermit.sol';
import {IPoolAddressesProvider} from '@aave/core-v3/contracts/interfaces/IPoolAddressesProvider.sol';
import {SafeERC20, IERC20} from 'lib/solidity-utils/src/contracts/oz-common/SafeERC20.sol';
import {SafeMath} from '@aave/core-v3/contracts/dependencies/openzeppelin/contracts/SafeMath.sol';
import {BaseGluexBuyAdapter} from './BaseGluexBuyAdapter.sol';
import {ReentrancyGuard} from '@aave/periphery-v3/contracts/dependencies/openzeppelin/ReentrancyGuard.sol';

/**
 * @title GluexRepayAdapter
 * @notice Gluex Adapter to perform a repay of a debt with collateral.
 * @author Aave
 **/
contract GluexRepayAdapter is BaseGluexBuyAdapter, ReentrancyGuard {
  using SafeMath for uint256;
  using SafeERC20 for IERC20;

  struct RepayParams {
    address collateralAsset;
    uint256 collateralAmount;
    uint256 rateMode;
    PermitSignature permitSignature;
    bool useEthPath;
  }

  constructor(
    IPoolAddressesProvider addressesProvider,
    address gluexRouter,
    address owner
  ) BaseGluexBuyAdapter(addressesProvider, gluexRouter) {
    transferOwnership(owner);
  }

  /**
   * @dev Uses the received funds from the flash loan to repay a debt on the protocol on behalf of the user. Then pulls
   * the collateral from the user and swaps it to the debt asset to repay the flash loan.
   * The user should give this contract allowance to pull the ATokens in order to withdraw the underlying asset, swap it
   * and repay the flash loan.
   * Supports only one asset on the flash loan.
   * @param asset The address of the flash-borrowed asset
   * @param amount The amount of the flash-borrowed asset
   * @param premium The fee of the flash-borrowed asset
   * @param initiator The address of the flashloan initiator
   * @param params The byte-encoded params passed when initiating the flashloan
   * @return True if the execution of the operation succeeds, false otherwise
   *   IERC20 debtAsset Address of the debt asset
   *   uint256 debtRepayAmount Amount of debt to be repaid
   *   uint256 rateMode Rate mode of the debt to be repaid
   *   bytes gluexData Gluex Data
   *   PermitSignature permitParams Struct containing the permit signatures, set to all zeroes if not used
   */
  function executeOperation(
    address asset,
    uint256 amount,
    uint256 premium,
    address initiator,
    bytes calldata params
  ) external override nonReentrant returns (bool) {
    require(msg.sender == address(POOL), 'CALLER_MUST_BE_POOL');

    uint256 collateralAmount = amount;

    IERC20 collateralAsset = IERC20(asset);

    _swapAndRepay(params, premium, initiator, collateralAsset, collateralAmount);

    return true;
  }

  /**
   * @dev Swaps the user collateral for the debt asset and then repay the debt on the protocol on behalf of the user
   * without using flash loans. This method can be used when the temporary transfer of the collateral asset to this
   * contract does not affect the user position.
   * The user should give this contract allowance to pull the ATokens in order to withdraw the underlying asset
   * @param collateralAsset Address of asset to be swapped
   * @param debtAsset Address of debt asset
   * @param collateralAmount max Amount of the collateral to be swapped
   * @param debtRepayAmount Amount of the debt to be repaid, or maximum amount when repaying entire debt
   * @param gluexData Data for Gluex Router
   * @param permitSignature struct containing the permit signature
   */
  function swapAndRepay(
    IERC20 collateralAsset,
    IERC20 debtAsset,
    uint256 collateralAmount,
    uint256 debtRepayAmount,
    bytes calldata gluexData,
    PermitSignature calldata permitSignature
  ) external nonReentrant {
    debtRepayAmount = getDebtRepayAmount(
      debtAsset,
      2, // Variable rate mode only
      debtRepayAmount,
      msg.sender
    );

    // Pull aTokens from user
    _pullATokenAndWithdraw(address(collateralAsset), msg.sender, collateralAmount, permitSignature);
    
    //buy debt asset using collateral asset
    (uint256 amountSold, uint256 amountBought) = _buyOnGluex(
      gluexData,
      collateralAsset,
      debtAsset
    );

    uint256 collateralBalanceLeft = collateralAmount - amountSold;

    //deposit collateral back in the pool, if left after the swap(buy)
    if (collateralBalanceLeft > 0) {
      IERC20(collateralAsset).safeApprove(address(POOL), collateralBalanceLeft);
      POOL.deposit(address(collateralAsset), collateralBalanceLeft, msg.sender, 0);
      IERC20(collateralAsset).safeApprove(address(POOL), 0);
    }

    // Repay debt. Approves 0 first to comply with tokens that implement the anti frontrunning approval fix
    IERC20(debtAsset).safeApprove(address(POOL), debtRepayAmount);
    POOL.repay(address(debtAsset), debtRepayAmount, 2, msg.sender); // Variable rate mode only
    IERC20(debtAsset).safeApprove(address(POOL), 0);

    {
      //transfer excess of debtAsset back to the user, if any
      uint256 debtAssetExcess = amountBought - debtRepayAmount;
      if (debtAssetExcess > 0) {
        IERC20(debtAsset).safeTransfer(msg.sender, debtAssetExcess);
      }
    }
  }

  /**
   * @dev Perform the repay of the debt, pulls the initiator collateral and swaps to repay the flash loan
   * @param params Params for the swap and repay
   * @param premium Fee of the flash loan
   * @param initiator Address of the user
   * @param collateralAsset Address of token to be swapped
   * @param collateralAmount Amount of the reserve to be swapped(flash loan amount)
   */

  function _swapAndRepay(
    bytes calldata params,
    uint256 premium,
    address initiator,
    IERC20 collateralAsset,
    uint256 collateralAmount
  ) private {
    (
      IERC20 debtAsset,
      uint256 debtRepayAmount,
      uint256 rateMode,
      bytes memory gluexData,
      PermitSignature memory permitSignature
    ) = abi.decode(params, (IERC20, uint256, uint256, bytes, PermitSignature));

    debtRepayAmount = getDebtRepayAmount(
      debtAsset,
      rateMode,
      debtRepayAmount,
      initiator
    );

    (uint256 amountSold, uint256 amountBought) = _buyOnGluex(gluexData, collateralAsset, debtAsset);

    // Repay debt. Approves for 0 first to comply with tokens that implement the anti frontrunning approval fix.
    IERC20(debtAsset).safeApprove(address(POOL), debtRepayAmount);
    POOL.repay(address(debtAsset), debtRepayAmount, rateMode, initiator);
    IERC20(debtAsset).safeApprove(address(POOL), 0);

    uint256 neededForFlashLoanRepay = amountSold.add(premium);

    // Pull aTokens from user
    _pullATokenAndWithdraw(
      address(collateralAsset),
      initiator,
      neededForFlashLoanRepay,
      permitSignature
    );

    {
      //transfer excess of debtAsset back to the user, if any
      uint256 debtAssetExcess = amountBought - debtRepayAmount;
      if (debtAssetExcess > 0) {
        IERC20(debtAsset).safeTransfer(initiator, debtAssetExcess);
      }
    }

    // Repay flashloan. Approves for 0 first to comply with tokens that implement the anti frontrunning approval fix.
    IERC20(collateralAsset).safeApprove(address(POOL), 0);
    IERC20(collateralAsset).safeApprove(address(POOL), collateralAmount.add(premium));
  }

  function getDebtRepayAmount(
    IERC20 debtAsset,
    uint256 rateMode,
    uint256 debtRepayAmount,
    address initiator
  ) private view returns (uint256) {
    DataTypes.ReserveData memory debtReserveData = _getReserveData(address(debtAsset));

    address debtToken = DataTypes.InterestRateMode(rateMode) == DataTypes.InterestRateMode.STABLE
      ? debtReserveData.stableDebtTokenAddress
      : debtReserveData.variableDebtTokenAddress;

    uint256 currentDebt = IERC20(debtToken).balanceOf(initiator);

    require(debtRepayAmount <= currentDebt, 'INVALID_DEBT_REPAY_AMOUNT');

    return debtRepayAmount;
  }
}