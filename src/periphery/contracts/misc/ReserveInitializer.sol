// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20} from "solidity-utils/contracts/oz-common/interfaces/IERC20.sol";
import {IERC20Metadata} from "solidity-utils/contracts/oz-common/interfaces/IERC20Metadata.sol";
import {Ownable} from "@aave/core-v3/contracts/dependencies/openzeppelin/contracts/Ownable.sol";
import {SafeERC20} from 'solidity-utils/contracts/oz-common/SafeERC20.sol';
import {IWrappedHypeGateway} from 'src/periphery/contracts/misc/interfaces/IWrappedHypeGateway.sol';
import {IPoolConfigurator} from "aave-v3-core/contracts/interfaces/IPoolConfigurator.sol";
import {IPool} from "aave-v3-core/contracts/interfaces/IPool.sol";
import {ConfiguratorInputTypes} from "@aave/core-v3/contracts/protocol/libraries/types/ConfiguratorInputTypes.sol";

/**
 * @title ReserveInitializer
 * @notice Contract to initialize reserves and handle token transfers, including HYPE to WHYPE wrapping
 */
contract ReserveInitializer is Ownable {
    using SafeERC20 for IERC20;

    IWrappedHypeGateway public immutable WRAPPED_TOKEN_GATEWAY;
    IPoolConfigurator public immutable POOL_CONFIGURATOR;
    IPool public immutable POOL;

    constructor(
        address wrappedTokenGateway,
        address poolConfigurator,
        address pool
    ) Ownable() {
        WRAPPED_TOKEN_GATEWAY = IWrappedHypeGateway(wrappedTokenGateway);
        POOL_CONFIGURATOR = IPoolConfigurator(poolConfigurator);
        POOL = IPool(pool);
    }

    /**
     * @notice Initializes reserves by transferring tokens to the specified address
     * @param inputs The reserve configuration inputs
     * @param initialAmounts Initial amounts to supply to the pool
     */
    function batchInitReserves(
        ConfiguratorInputTypes.InitReserveInput[] memory inputs,
        uint256[] memory initialAmounts
    ) external payable onlyOwner {
        // Initialize reserves first
        IPoolConfigurator(POOL_CONFIGURATOR).initReserves(inputs);

        // Supply initial amounts to pool
        for (uint256 i = 0; i < inputs.length; i++) {
            if (initialAmounts[i] > 0) {
                address underlyingAsset = inputs[i].underlyingAsset;

                if (underlyingAsset == address(WRAPPED_TOKEN_GATEWAY.getWHYPEAddress()) && msg.value > 0) {
                    // For HYPE tokens, wrap them to WHYPE first
                    WRAPPED_TOKEN_GATEWAY.depositHYPE{value: msg.value}(address(POOL), msg.sender, 0);
                } else {
                    require(IERC20(underlyingAsset).balanceOf(msg.sender) >= initialAmounts[i], string(abi.encodePacked("Insufficient balance of ", IERC20Metadata(underlyingAsset).symbol())));
                    // Approve pool to spend tokens
                    IERC20(underlyingAsset).safeIncreaseAllowance(address(POOL), initialAmounts[i]);
                    // Supply to pool
                    POOL.supply(underlyingAsset, initialAmounts[i], msg.sender, 0);
                }
            }
        }
    }
}
