// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.10;

import {MintableLimitERC20} from "src/testnet/MintableLimitERC20.sol";

contract FaucetReceiver {
    constructor(address[] memory _tokens, uint256 _mintAmount) {
        for (uint256 i = 0; i < _tokens.length; i++) {
            MintableLimitERC20 token = MintableLimitERC20(_tokens[i]);
            token.mint(msg.sender, _mintAmount);
        }
    }
}