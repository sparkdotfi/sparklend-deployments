// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.10;

interface IStHYPE {
    function getPooledHYPEByShares(uint256 _sharesAmount) external view returns (uint256);
    function totalSupply() external view returns (uint256);
    function totalShares() external view returns (uint256);
    function balanceToShareDecimals() external view returns (uint256);
}