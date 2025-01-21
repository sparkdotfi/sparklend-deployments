// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

/**
 * @title IWrappedHypeGateway   
 * @author HypurrFi
 * @notice Defines the basic interface for a WHYPE Gateway
 */
interface IWrappedHypeGateway {
  /**
   * @dev Deposits HYPE into the protocol
   * @param onBehalfOf The address that will receive the aTokens
   * @param referralCode Code used to register the integrator originating the operation, for potential rewards.
   *   0 if the action is executed directly by the user, without any middle-man
   */
  function depositHYPE(
    address,
    address onBehalfOf,
    uint16 referralCode
  ) external payable;

  /**
   * @dev Withdraws HYPE from the protocol to the recipient address
   * @param amount The amount of WHYPE to withdraw
   * @param to The address that will receive the HYPE
   */
  function withdrawHYPE(
    address,
    uint256 amount,
    address to
  ) external;

  /**
   * @dev Withdraws HYPE from the protocol with permit signature
   * @param amount The amount of WHYPE to withdraw
   * @param to The address that will receive the HYPE
   * @param deadline The deadline timestamp for the signature
   * @param permitV The V parameter of ERC712 permit sig
   * @param permitR The R parameter of ERC712 permit sig
   * @param permitS The S parameter of ERC712 permit sig
   */
  function withdrawHYPEWithPermit(
    address,
    uint256 amount,
    address to,
    uint256 deadline,
    uint8 permitV,
    bytes32 permitR,
    bytes32 permitS
  ) external;

  /**
   * @dev Borrows HYPE from the protocol
   * @param amount The amount of HYPE to borrow
   * @param interestRateMode The interest rate mode (Stable = 1, Variable = 2)
   * @param referralCode The referral code for potential rewards
   */
  function borrowHYPE(
    address,
    uint256 amount,
    uint256 interestRateMode,
    uint16 referralCode
  ) external;

  /**
   * @dev Repays HYPE to the protocol
   * @param amount The amount to repay
   * @param rateMode The interest rate mode (Stable = 1, Variable = 2)
   * @param onBehalfOf The address of the user who will get their debt reduced
   */
  function repayHYPE(
    address,
    uint256 amount,
    uint256 rateMode,
    address onBehalfOf
  ) external payable;

  /**
   * @dev Returns the WHYPE address used by the gateway
   * @return The address of the WHYPE token
   */
  function getWHYPEAddress() external view returns (address);

  /**
   * @dev Allows owner to rescue tokens sent to the contract
   * @param token The address of the token
   * @param to The address that will receive the tokens
   * @param amount The amount of tokens to transfer
   */
  function emergencyTokenTransfer(
    address token,
    address to,
    uint256 amount
  ) external;

  /**
   * @dev Allows owner to rescue native tokens sent to the contract
   * @param to The address that will receive the native tokens
   * @param amount The amount to transfer
   */
  function emergencyEtherTransfer(
    address to,
    uint256 amount
  ) external;
}