// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

interface ILiquidator {
    /// @notice Performs a liquidation using a flash swap
    /// @param collateralAsset address of the collateral asset to be liquidated
    /// @param debtAsset address of the debt asset to be repaid
    /// @param user address of the user to be liquidated
    /// @param debtToCover amount of debt asset to repay in exchange for collateral
    /// @param swapPath encoded path of pools to swap collateral through, see: https://docs.uniswap.org/contracts/v3/guides/swaps/multihop-swaps
    /// @param liqPath either "kittenswap" or "hyperswap" or "usdxlFlashMinter"
    function liquidate(
        address collateralAsset,
        address debtAsset,
        address user,
        uint256 debtToCover,
        bytes calldata swapPath,
        string calldata liqPath
    )
    external
    returns (address finalToken, int256 finalGain);

    /// @notice Approves the lending pool to spend tokens
    /// @param token The address of the token to approve
    function approvePool(address token) external;
}