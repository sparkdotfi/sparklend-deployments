// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

interface ILiquidator {
    /// @notice Performs a liquidation using a Uniswap v3 flash swap
    /// @param collateral address of the collateral asset to be liquidated
    /// @param debtAsset address of the debt asset to be repaid
    /// @param user address of the user to be liquidated
    /// @param debtToCover amount of debt asset to repay in exchange for collateral
    /// @param liquidatedCollateralAmount amount of collateral to liquidate
    /// @param liquidator address that will receive the liquidated collateral
    /// @param receiveAToken true if the liquidator wants to receive aTokens, false for underlying asset
    /// @param swapPath encoded path of pools to swap collateral through, see: https://docs.uniswap.org/contracts/v3/guides/swaps/multihop-swaps
    function liquidate(
        address collateral,
        address debtAsset,
        address user,
        uint256 debtToCover,
        uint256 liquidatedCollateralAmount,
        address liquidator,
        bool receiveAToken,
        bytes calldata swapPath
    ) external returns (int256 collateralGain);

    /// @notice Approves the lending pool to spend tokens
    /// @param token The address of the token to approve
    function approvePool(
        address token
    ) external;

    function testGetAmountIn() external;
} 