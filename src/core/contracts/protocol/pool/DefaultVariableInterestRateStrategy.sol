// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import {IDefaultInterestRateStrategy} from "aave-v3-core/contracts/interfaces/IDefaultInterestRateStrategy.sol";
import {DataTypes} from "aave-v3-core/contracts/protocol/libraries/types/DataTypes.sol";
import {WadRayMath} from "aave-v3-core/contracts/protocol/libraries/math/WadRayMath.sol";
import {IERC20} from '@aave/core-v3/contracts/dependencies/openzeppelin/contracts/IERC20.sol';
import {IPoolAddressesProvider} from "aave-v3-core/contracts/interfaces/IPoolAddressesProvider.sol";
import {Errors} from "aave-v3-core/contracts/protocol/libraries/helpers/Errors.sol";

contract DefaultVariableInterestRateStrategy is IDefaultInterestRateStrategy {
    using WadRayMath for uint256;

  /// @inheritdoc IDefaultInterestRateStrategy
  uint256 public immutable OPTIMAL_USAGE_RATIO;

  /// @inheritdoc IDefaultInterestRateStrategy
  uint256 public immutable OPTIMAL_STABLE_TO_TOTAL_DEBT_RATIO;

  /// @inheritdoc IDefaultInterestRateStrategy
  uint256 public immutable MAX_EXCESS_USAGE_RATIO;

  /// @inheritdoc IDefaultInterestRateStrategy
  uint256 public immutable MAX_EXCESS_STABLE_TO_TOTAL_DEBT_RATIO;

  IPoolAddressesProvider public immutable ADDRESSES_PROVIDER;

  // Base variable borrow rate when usage rate = 0. Expressed in ray
  uint256 internal immutable _baseVariableBorrowRate;

  // Slope of the variable interest curve when usage ratio > 0 and <= OPTIMAL_USAGE_RATIO. Expressed in ray
  uint256 internal immutable _variableRateSlope1;

  // Slope of the variable interest curve when usage ratio > OPTIMAL_USAGE_RATIO. Expressed in ray
  uint256 internal immutable _variableRateSlope2;

  // Slope of the stable interest curve when usage ratio > 0 and <= OPTIMAL_USAGE_RATIO. Expressed in ray
  uint256 internal immutable _stableRateSlope1;

  // Slope of the stable interest curve when usage ratio > OPTIMAL_USAGE_RATIO. Expressed in ray
  uint256 internal immutable _stableRateSlope2;

  // Premium on top of `_variableRateSlope1` for base stable borrowing rate
  uint256 internal immutable _baseStableRateOffset;

  // Additional premium applied to stable rate when stable debt surpass `OPTIMAL_STABLE_TO_TOTAL_DEBT_RATIO`
  uint256 internal immutable _stableRateExcessOffset;

  /**
   * @dev Constructor.
   * @param provider The address of the PoolAddressesProvider contract
   * @param optimalUsageRatio The optimal usage ratio
   * @param baseVariableBorrowRate The base variable borrow rate
   * @param variableRateSlope1 The variable rate slope below optimal usage ratio
   * @param variableRateSlope2 The variable rate slope above optimal usage ratio
   * @param stableRateSlope1 The stable rate slope below optimal usage ratio
   * @param stableRateSlope2 The stable rate slope above optimal usage ratio
   * @param baseStableRateOffset The premium on top of variable rate for base stable borrowing rate
   * @param stableRateExcessOffset The premium on top of stable rate when there stable debt surpass the threshold
   * @param optimalStableToTotalDebtRatio The optimal stable debt to total debt ratio of the reserve
   */
  constructor(
    IPoolAddressesProvider provider,
    uint256 optimalUsageRatio,
    uint256 baseVariableBorrowRate,
    uint256 variableRateSlope1,
    uint256 variableRateSlope2,
    uint256 stableRateSlope1,
    uint256 stableRateSlope2,
    uint256 baseStableRateOffset,
    uint256 stableRateExcessOffset,
    uint256 optimalStableToTotalDebtRatio
  ) {
    require(WadRayMath.RAY >= optimalUsageRatio, Errors.INVALID_OPTIMAL_USAGE_RATIO);
    require(
      WadRayMath.RAY >= optimalStableToTotalDebtRatio,
      Errors.INVALID_OPTIMAL_STABLE_TO_TOTAL_DEBT_RATIO
    );
    OPTIMAL_USAGE_RATIO = optimalUsageRatio;
    MAX_EXCESS_USAGE_RATIO = WadRayMath.RAY - optimalUsageRatio;
    OPTIMAL_STABLE_TO_TOTAL_DEBT_RATIO = optimalStableToTotalDebtRatio;
    MAX_EXCESS_STABLE_TO_TOTAL_DEBT_RATIO = WadRayMath.RAY - optimalStableToTotalDebtRatio;
    ADDRESSES_PROVIDER = provider;
    _baseVariableBorrowRate = baseVariableBorrowRate;
    _variableRateSlope1 = variableRateSlope1;
    _variableRateSlope2 = variableRateSlope2;
    _stableRateSlope1 = stableRateSlope1;
    _stableRateSlope2 = stableRateSlope2;
    _baseStableRateOffset = baseStableRateOffset;
    _stableRateExcessOffset = stableRateExcessOffset;
  }

    struct CalcInterestRatesLocalVars {
      uint256 availableLiquidity;
      uint256 totalDebt;
      uint256 currentVariableBorrowRate;
      uint256 currentStableBorrowRate;
      uint256 currentLiquidityRate;
      uint256 borrowUsageRatio;
      uint256 supplyUsageRatio;
      uint256 stableToTotalDebtRatio;
      uint256 availableLiquidityPlusDebt;
    }

    function calculateInterestRates(
        DataTypes.CalculateInterestRatesParams memory params
    ) external view override returns (
        uint256 liquidityRate,
        uint256 stableBorrowRate,
        uint256 variableBorrowRate
    ) {
        uint256 totalDebt = params.totalStableDebt + params.totalVariableDebt;
        uint256 utilizationRate = totalDebt == 0 
            ? 0 
            : totalDebt.rayDiv(
              (
                IERC20(params.reserve).balanceOf(params.aToken) +
                params.liquidityAdded -
                params.liquidityTaken
               ) +
              totalDebt
            );

        // Calculate variable borrow rate
        variableBorrowRate = _calculateVariableBorrowRate(utilizationRate);

        // Stable borrowing is disabled
        stableBorrowRate = 0;

        // Calculate supply (liquidity) rate
        liquidityRate = _calculateLiquidityRate(
            utilizationRate,
            variableBorrowRate,
            stableBorrowRate,
            params.totalStableDebt,
            params.totalVariableDebt,
            params.averageStableBorrowRate,
            params.reserveFactor
        );
    }

    function _calculateVariableBorrowRate(
        uint256 utilizationRate
    ) internal view returns (uint256) {
        if (utilizationRate <= OPTIMAL_USAGE_RATIO) {
            return _baseVariableBorrowRate + 
                   (utilizationRate.rayMul(_variableRateSlope1).rayDiv(OPTIMAL_USAGE_RATIO));
        } else {
            return _baseVariableBorrowRate +
                   _variableRateSlope1 +
                   ((utilizationRate - OPTIMAL_USAGE_RATIO).rayMul(_variableRateSlope2)
                   .rayDiv(WadRayMath.RAY - OPTIMAL_USAGE_RATIO));
        }
    }

    function _calculateLiquidityRate(
        uint256 utilizationRate,
        uint256 variableBorrowRate,
        uint256 stableBorrowRate,
        uint256 totalStableDebt,
        uint256 totalVariableDebt,
        uint256 averageStableBorrowRate,
        uint256 reserveFactor
    ) internal pure returns (uint256) {
        uint256 totalDebt = totalStableDebt + totalVariableDebt;
        if (totalDebt == 0) return 0;

        uint256 weightedVariableRate = variableBorrowRate
            .rayMul(totalVariableDebt.rayDiv(totalDebt));
        uint256 weightedStableRate = averageStableBorrowRate
            .rayMul(totalStableDebt.rayDiv(totalDebt));

        uint256 overallBorrowRate = weightedVariableRate + weightedStableRate;
        uint256 overallRate = utilizationRate.rayMul(overallBorrowRate);

        return overallRate.rayMul(WadRayMath.RAY - reserveFactor);
    }

    function getVariableRateSlope1() external view returns (uint256) {
        return _variableRateSlope1;
    }

    function getVariableRateSlope2() external view returns (uint256) {
        return _variableRateSlope2;
    }

    function getStableRateSlope1() external view returns (uint256) {
        return _stableRateSlope1;
    }

    function getStableRateSlope2() external view returns (uint256) {
        return _stableRateSlope2;
    }

    function getBaseStableBorrowRate() external view returns (uint256) {
        return _variableRateSlope1 + _baseStableRateOffset;
    }

    /// @inheritdoc IDefaultInterestRateStrategy
    function getStableRateExcessOffset() external view returns (uint256) {
      return _stableRateExcessOffset;
    }

    function getBaseVariableBorrowRate() external view returns (uint256) {
        return _baseVariableBorrowRate;
    }

    function getMaxVariableBorrowRate() external view returns (uint256) {
        return _baseVariableBorrowRate + _variableRateSlope1 + _variableRateSlope2;
    }
}
