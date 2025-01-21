// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title IWHYPE
 * @author HypurrFi
 * @notice Interface for the Wrapped HYPE (WHYPE) contract
 */
interface IWHYPE {
    /**
     * @dev Emitted when HYPE is wrapped to WHYPE
     * @param src The address that wrapped the HYPE
     * @param wad The amount of HYPE wrapped
     */
    event Deposit(address indexed src, uint256 wad);

    /**
     * @dev Emitted when WHYPE is unwrapped back to HYPE
     * @param dst The address that unwrapped the WHYPE
     * @param wad The amount of WHYPE unwrapped
     */
    event Withdrawal(address indexed dst, uint256 wad);

    /**
     * @dev Deposit HYPE and mint WHYPE
     */
    function deposit() external payable;

    /**
     * @dev Withdraw HYPE by burning WHYPE
     * @param wad The amount of WHYPE to burn
     */
    function withdraw(uint256 wad) external;

    /**
     * @dev Fallback function to handle direct HYPE transfers
     */
    receive() external payable;

    /**
     * @dev Returns the amount of WHYPE tokens in existence
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the amount of WHYPE tokens owned by account
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves amount WHYPE tokens from the caller's account to recipient
     * @return True if the transfer succeeded
     */
    function transfer(address recipient, uint256 amount) external returns (bool);

    /**
     * @dev Returns the remaining number of WHYPE tokens that spender will be allowed to spend on behalf of owner
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev Sets amount as the allowance of spender over the caller's WHYPE tokens
     * @return True if the approval succeeded
     */
    function approve(address spender, uint256 amount) external returns (bool);

    /**
     * @dev Moves amount WHYPE tokens from sender to recipient using the allowance mechanism
     * @return True if the transfer succeeded
     */
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
}
