// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.10;

import {IPool} from "@aave/core-v3/contracts/interfaces/IPool.sol";

/**
 * @title IHyFiPool
 * @author HypurrFi
 * @notice Interface for the HyFi pool, extending Aave's pool interface
 */
interface IHyFiPool is IPool {
    /**
     * @dev Emitted when a borrow occurs
     * @param user The address of the user initiating the borrow
     * @param asset The address of the asset being borrowed
     * @param amount The amount being borrowed
     * @param interestRateMode The interest rate mode (stable or variable)
     * @param borrowRate The borrow rate at the moment of the borrow
     */
    event Borrow(
        address indexed user,
        address indexed asset,
        uint256 amount,
        uint256 interestRateMode,
        uint256 borrowRate
    );

    /**
     * @dev Emitted when a supply occurs
     * @param user The address of the user initiating the supply
     * @param asset The address of the asset being supplied
     * @param amount The amount being supplied
     * @param referralCode The referral code used
     */
    event Supply(
        address indexed user,
        address indexed asset,
        uint256 amount,
        uint16 referralCode
    );
}
