// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import { IDefaultInterestRateStrategy } from "./interfaces/IDefaultInterestRateStrategy.sol";
import { DataTypes } from "./libraries/DataTypes.sol";
import { WadRayMath } from "./libraries/WadRayMath.sol";

contract DefaultVariableInterestRateStrategy is IDefaultInterestRateStrategy {
    using WadRayMath for uint256;

    // Constants for calculations (all in RAY)
    uint256 public immutable OPTIMAL_USAGE_RATIO;
    uint256 public immutable OPTIMAL_STABLE_TO_TOTAL_DEBT_RATIO;
    uint256 public immutable BASE_VARIABLE_BORROW_RATE;
    uint256 public immutable VARIABLE_RATE_SLOPE1;
    uint256 public immutable VARIABLE_RATE_SLOPE2;
    uint256 public immutable STABLE_RATE_SLOPE1;
    uint256 public immutable STABLE_RATE_SLOPE2;
    uint256 public immutable BASE_STABLE_BORROW_RATE;

    constructor(
        uint256 optimalUsageRatio,
        uint256 baseVariableBorrowRate,
        uint256 variableRateSlope1,
        uint256 variableRateSlope2,
        uint256 stableRateSlope1,
        uint256 stableRateSlope2,
        uint256 baseStableBorrowRate,
        uint256 optimalStableToTotalDebtRatio
    ) {
        OPTIMAL_USAGE_RATIO = optimalUsageRatio;
        BASE_VARIABLE_BORROW_RATE = baseVariableBorrowRate;
        VARIABLE_RATE_SLOPE1 = variableRateSlope1;
        VARIABLE_RATE_SLOPE2 = variableRateSlope2;
        STABLE_RATE_SLOPE1 = stableRateSlope1;
        STABLE_RATE_SLOPE2 = stableRateSlope2;
        BASE_STABLE_BORROW_RATE = baseStableBorrowRate;
        OPTIMAL_STABLE_TO_TOTAL_DEBT_RATIO = optimalStableToTotalDebtRatio;
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
            : totalDebt.rayDiv(params.availableLiquidity + totalDebt);

        // Calculate variable borrow rate
        variableBorrowRate = _calculateVariableBorrowRate(utilizationRate);

        // Calculate stable borrow rate
        stableBorrowRate = _calculateStableBorrowRate(
            utilizationRate,
            params.totalStableDebt,
            totalDebt
        );

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
            return BASE_VARIABLE_BORROW_RATE + 
                   (utilizationRate.rayMul(VARIABLE_RATE_SLOPE1).rayDiv(OPTIMAL_USAGE_RATIO));
        } else {
            return BASE_VARIABLE_BORROW_RATE +
                   VARIABLE_RATE_SLOPE1 +
                   ((utilizationRate - OPTIMAL_USAGE_RATIO).rayMul(VARIABLE_RATE_SLOPE2)
                   .rayDiv(WadRayMath.RAY - OPTIMAL_USAGE_RATIO));
        }
    }

    function _calculateStableBorrowRate(
        uint256 utilizationRate,
        uint256 totalStableDebt,
        uint256 totalDebt
    ) internal view returns (uint256) {
        uint256 stableToTotalDebtRatio = totalDebt == 0 
            ? 0 
            : totalStableDebt.rayDiv(totalDebt);

        uint256 baseRate = BASE_STABLE_BORROW_RATE +
            STABLE_RATE_SLOPE1.rayMul(utilizationRate.rayDiv(OPTIMAL_USAGE_RATIO));

        if (utilizationRate > OPTIMAL_USAGE_RATIO) {
            baseRate += STABLE_RATE_SLOPE2.rayMul(
                (utilizationRate - OPTIMAL_USAGE_RATIO).rayDiv(WadRayMath.RAY - OPTIMAL_USAGE_RATIO)
            );
        }

        if (stableToTotalDebtRatio > OPTIMAL_STABLE_TO_TOTAL_DEBT_RATIO) {
            baseRate += STABLE_RATE_SLOPE2.rayMul(
                (stableToTotalDebtRatio - OPTIMAL_STABLE_TO_TOTAL_DEBT_RATIO)
                .rayDiv(WadRayMath.RAY - OPTIMAL_STABLE_TO_TOTAL_DEBT_RATIO)
            );
        }

        return baseRate;
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
        return VARIABLE_RATE_SLOPE1;
    }

    function getVariableRateSlope2() external view returns (uint256) {
        return VARIABLE_RATE_SLOPE2;
    }

    function getStableRateSlope1() external view returns (uint256) {
        return STABLE_RATE_SLOPE1;
    }

    function getStableRateSlope2() external view returns (uint256) {
        return STABLE_RATE_SLOPE2;
    }

    function getBaseStableBorrowRate() external view returns (uint256) {
        return BASE_STABLE_BORROW_RATE;
    }

    function getBaseVariableBorrowRate() external view returns (uint256) {
        return BASE_VARIABLE_BORROW_RATE;
    }

    function getMaxVariableBorrowRate() external view returns (uint256) {
        return BASE_VARIABLE_BORROW_RATE + VARIABLE_RATE_SLOPE1 + VARIABLE_RATE_SLOPE2;
    }
}
