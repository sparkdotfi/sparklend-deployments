// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.10;

import {Ownable} from "@aave/core-v3/contracts/dependencies/openzeppelin/contracts/Ownable.sol";
import {IERC20} from "@aave/core-v3/contracts/dependencies/openzeppelin/contracts/IERC20.sol";
import {GPv2SafeERC20} from "@aave/core-v3/contracts/dependencies/gnosis/contracts/GPv2SafeERC20.sol";
import {IWHYPE} from "src/core/contracts/misc/interfaces/IWHYPE.sol";
import {IPool} from "@aave/core-v3/contracts/interfaces/IPool.sol";
import {IAToken} from "@aave/core-v3/contracts/interfaces/IAToken.sol";
import {ReserveConfiguration} from "@aave/core-v3/contracts/protocol/libraries/configuration/ReserveConfiguration.sol";
import {UserConfiguration} from "@aave/core-v3/contracts/protocol/libraries/configuration/UserConfiguration.sol";
import {DataTypes} from "@aave/core-v3/contracts/protocol/libraries/types/DataTypes.sol";
import {IWrappedTokenGatewayV3} from "@aave/periphery-v3/contracts/misc/interfaces/IWrappedTokenGatewayV3.sol";
import {IWrappedHypeGateway} from "src/periphery/contracts/misc/interfaces/IWrappedHypeGateway.sol";
import {DataTypesHelper} from "@aave/periphery-v3/contracts/libraries/DataTypesHelper.sol";

/**
 * @dev This contract is an upgrade of the WrappedTokenGatewayV3 contract, with an immutable pool address.
 * This contract keeps the same interface of the deprecated WrappedTokenGatewayV3 contract.
 */
contract WrappedHypeGateway is IWrappedTokenGatewayV3, IWrappedHypeGateway, Ownable {
    using ReserveConfiguration for DataTypes.ReserveConfigurationMap;
    using UserConfiguration for DataTypes.UserConfigurationMap;
    using GPv2SafeERC20 for IERC20;

    IWHYPE internal immutable WHYPE;
    IPool internal immutable POOL;

    /**
     * @dev Sets the WHYPE address and the PoolAddressesProvider address. Infinite approves pool.
     * @param whype Address of the Wrapped HYPE contract
     * @param owner Address of the owner of this contract
     *
     */
    constructor(address whype, address owner, IPool pool) {
        WHYPE = IWHYPE(payable(whype));
        POOL = pool;
        transferOwnership(owner);
        IWHYPE(payable(whype)).approve(address(pool), type(uint256).max);
    }

    /**
     * @notice Deprecated: Use depositHYPE() instead. Left for backwards compatibility with AAVE UI
     */
    function depositETH(address, address onBehalfOf, uint16 referralCode) external payable override {
        depositHYPE(address(0), onBehalfOf, referralCode);
    }

    /**
     * @notice Deprecated: Use withdrawHYPE() instead. Left for backwards compatibility with AAVE UI
     */
    function withdrawETH(address, uint256 amount, address to) external override {
        withdrawHYPE(address(0), amount, to);
    }

    /**
     * @notice Deprecated: Use repayHYPE() instead. Left for backwards compatibility with AAVE UI
     */
    function repayETH(address, uint256 amount, uint256 rateMode, address onBehalfOf) external payable override {
        repayHYPE(address(0), amount, rateMode, onBehalfOf);
    }

    /**
     * @notice Deprecated: Use borrowHYPE() instead. Left for backwards compatibility with AAVE UI
     */
    function borrowETH(address, uint256 amount, uint256 interestRateMode, uint16 referralCode) external override {
        borrowHYPE(address(0), amount, interestRateMode, referralCode);
    }

    /**
     * @notice Deprecated: Use withdrawHYPEWithPermit() instead. Left for backwards compatibility with AAVE UI
     */
    function withdrawETHWithPermit(
        address,
        uint256 amount,
        address to,
        uint256 deadline,
        uint8 permitV,
        bytes32 permitR,
        bytes32 permitS
    ) external override {
        withdrawHYPEWithPermit(address(0), amount, to, deadline, permitV, permitR, permitS);
    }

    /**
     * @notice Deprecated: Use getWHYPEAddress() instead. Left for backwards compatibility with AAVE UI
     * @dev Get WHYPE address used by WETHGateway
     */
    function getWETHAddress() external view returns (address) {
        return getWHYPEAddress();
    }

    /**
     * @notice Deprecated: Use emergencyTokenTransfer() instead. Left for backwards compatibility with AAVE UI
     * @dev transfer ERC20 tokens accidentally sent to this contract
     * @param to recipient of transferred tokens
     * @param amount amount of tokens to transfer
     */
    function emergencyEtherTransfer(address to, uint256 amount) external override onlyOwner {
        _safeTransferHYPE(to, amount);
    }

    /**
     * @dev deposits WHYPE into the reserve, using native HYPE. A corresponding amount of the overlying asset (aTokens)
     * is minted.
     * @param onBehalfOf address of the user who will receive the aTokens representing the deposit
     * @param referralCode integrators are assigned a referral code and can potentially receive rewards.
     *
     */
    function depositHYPE(address, address onBehalfOf, uint16 referralCode) public payable override {
        WHYPE.deposit{value: msg.value}();
        POOL.deposit(address(WHYPE), msg.value, onBehalfOf, referralCode);
    }

    /**
     * @dev withdraws the WHYPE _reserves of msg.sender.
     * @param amount amount of aWHYPE to withdraw and receive native HYPE
     * @param to address of the user who will receive native HYPE
     */
    function withdrawHYPE(address, uint256 amount, address to) public override {
        IAToken aWHYPE = IAToken(POOL.getReserveData(address(WHYPE)).aTokenAddress);
        uint256 userBalance = aWHYPE.balanceOf(msg.sender);
        uint256 amountToWithdraw = amount;

        // if amount is equal to uint(-1), the user wants to redeem everything
        if (amount == type(uint256).max) {
            amountToWithdraw = userBalance;
        }
        aWHYPE.transferFrom(msg.sender, address(this), amountToWithdraw);
        POOL.withdraw(address(WHYPE), amountToWithdraw, address(this));
        WHYPE.withdraw(amountToWithdraw);
        _safeTransferHYPE(to, amountToWithdraw);
    }

    /**
     * @dev repays a borrow on the WHYPE reserve, for the specified amount (or for the whole amount, if uint256(-1) is specified).
     * @param amount the amount to repay, or uint256(-1) if the user wants to repay everything
     * @param rateMode the rate mode to repay
     * @param onBehalfOf the address for which msg.sender is repaying
     */
    function repayHYPE(address, uint256 amount, uint256 rateMode, address onBehalfOf) public payable override {
        (uint256 stableDebt, uint256 variableDebt) =
            DataTypesHelper.getUserCurrentDebt(onBehalfOf, POOL.getReserveData(address(WHYPE)));

        uint256 paybackAmount =
            DataTypes.InterestRateMode(rateMode) == DataTypes.InterestRateMode.STABLE ? stableDebt : variableDebt;

        if (amount < paybackAmount) {
            paybackAmount = amount;
        }
        require(msg.value >= paybackAmount, "msg.value is less than repayment amount");
        WHYPE.deposit{value: paybackAmount}();
        POOL.repay(address(WHYPE), msg.value, rateMode, onBehalfOf);

        // refund remaining dust eth
        if (msg.value > paybackAmount) _safeTransferHYPE(msg.sender, msg.value - paybackAmount);
    }

    /**
     * @dev borrow WHYPE, unwraps to HYPE and send both the HYPE and DebtTokens to msg.sender, via `approveDelegation` and onBehalf argument in `Pool.borrow`.
     * @param amount the amount of HYPE to borrow
     * @param interestRateMode the interest rate mode
     * @param referralCode integrators are assigned a referral code and can potentially receive rewards
     */
    function borrowHYPE(address, uint256 amount, uint256 interestRateMode, uint16 referralCode) public override {
        POOL.borrow(address(WHYPE), amount, interestRateMode, referralCode, msg.sender);
        WHYPE.withdraw(amount);
        _safeTransferHYPE(msg.sender, amount);
    }

    /**
     * @dev withdraws the WHYPE _reserves of msg.sender.
     * @param amount amount of aWHYPE to withdraw and receive native HYPE
     * @param to address of the user who will receive native HYPE
     * @param deadline validity deadline of permit and so depositWithPermit signature
     * @param permitV V parameter of ERC712 permit sig
     * @param permitR R parameter of ERC712 permit sig
     * @param permitS S parameter of ERC712 permit sig
     */
    function withdrawHYPEWithPermit(
        address,
        uint256 amount,
        address to,
        uint256 deadline,
        uint8 permitV,
        bytes32 permitR,
        bytes32 permitS
    ) public override {
        IAToken aWHYPE = IAToken(POOL.getReserveData(address(WHYPE)).aTokenAddress);
        uint256 userBalance = aWHYPE.balanceOf(msg.sender);
        uint256 amountToWithdraw = amount;

        // if amount is equal to type(uint256).max, the user wants to redeem everything
        if (amount == type(uint256).max) {
            amountToWithdraw = userBalance;
        }
        // permit `amount` rather than `amountToWithdraw` to make it easier for front-ends and integrators
        aWHYPE.permit(msg.sender, address(this), amount, deadline, permitV, permitR, permitS);
        aWHYPE.transferFrom(msg.sender, address(this), amountToWithdraw);
        POOL.withdraw(address(WHYPE), amountToWithdraw, address(this));
        WHYPE.withdraw(amountToWithdraw);
        _safeTransferHYPE(to, amountToWithdraw);
    }

    /**
     * @dev transfer HYPE to an address, revert if it fails.
     * @param to recipient of the transfer
     * @param value the amount to send
     */
    function _safeTransferHYPE(address to, uint256 value) internal {
        (bool success,) = to.call{value: value}(new bytes(0));
        require(success, "HYPE_TRANSFER_FAILED");
    }

    /**
     * @dev transfer ERC20 from the utility contract, for ERC20 recovery in case of stuck tokens due
     * direct transfers to the contract address.
     * @param token token to transfer
     * @param to recipient of the transfer
     * @param amount amount to send
     */
    function emergencyTokenTransfer(address token, address to, uint256 amount) external onlyOwner {
        IERC20(token).safeTransfer(to, amount);
    }

    /**
     * @dev transfer native HYPE from the utility contract, for native HYPE recovery in case of stuck HYPE
     * due to selfdestructs or ether transfers to the pre-computed contract address before deployment.
     * @param to recipient of the transfer
     * @param amount amount to send
     */
    function emergencyHypeTransfer(address to, uint256 amount) external onlyOwner {
        _safeTransferHYPE(to, amount);
    }

    /**
     * @dev Get WHYPE address used by WrappedTokenGatewayV3
     */
    function getWHYPEAddress() public view returns (address) {
        return address(WHYPE);
    }

    /**
     * @dev Only WHYPE contract is allowed to transfer HYPE here. Prevent other addresses to send HYPE to this contract.
     */
    receive() external payable {
        require(msg.sender == address(WHYPE), "Receive not allowed");
    }

    /**
     * @dev Revert fallback calls
     */
    fallback() external payable {
        revert("Fallback not allowed");
    }
}
