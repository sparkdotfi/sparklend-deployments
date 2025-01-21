// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.10;

import { AToken } from "@aave/core-v3/contracts/protocol/tokenization/AToken.sol";
import { IPool } from "@aave/core-v3/contracts/interfaces/IPool.sol";

/**
 * @title HyToken
 * @author HypurrFi
 * @notice Implementation of the interest bearing token for the HypurrFi protocol
 * @dev It's based on the Aave AToken implementation
 */
contract HyToken is AToken {
    /**
     * @dev Constructor
     * @param pool The address of the Pool contract
     */
    constructor(
        IPool pool
    ) AToken(pool) {}
}