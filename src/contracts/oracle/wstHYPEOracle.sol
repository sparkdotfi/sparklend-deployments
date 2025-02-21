// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import {IStHYPE} from "src/contracts/oracle/interfaces/IStHYPE.sol";
import {IPoolAddressesProvider} from "@aave/core-v3/contracts/interfaces/IPoolAddressesProvider.sol";
import {IPriceOracleGetter} from "@aave/core-v3/contracts/interfaces/IPriceOracleGetter.sol";
import {AggregatorV3Interface} from "src/contracts/oracle/interfaces/AggregatorV3Interface.sol";
import {IEACAggregatorProxy} from "aave-v3-periphery/misc/interfaces/IEACAggregatorProxy.sol";

/**
 * @title WstHYPEOracle
 * @author HypurrFi
 * @notice Oracle for wstHYPE token
 * Price is calculated by:
 * 1. Getting HYPE/ETH price from Chainlink
 * 2. Getting the wstHYPE/stHYPE ratio using getStHYPEByWstHYPE()
 * 3. Getting the stHYPE/HYPE ratio from stHYPE contract
 * Final price = HYPE/ETH * (wstHYPE/stHYPE * stHYPE/HYPE)
 */
contract WstHYPEOracle is AggregatorV3Interface {
    address public constant HYPE_USD_PRICE_FEED = 0x1d0E4EA616A749c1620118F7d97c111e8ec36E8b;
    IStHYPE public constant ST_HYPE = IStHYPE(0xfFaa4a3D97fE9107Cef8a3F48c069F577Ff76cC1 );
    uint256 public constant PRECISION = 1e18;

    /**
     * @notice Get the price of wstHYPE in the base currency (ETH)
     * @return The price of wstHYPE in the base currency (ETH)
     */
    function latestAnswer() external view returns (int256) {
        uint256 totalHype = ST_HYPE.totalSupply();
        
        uint256 totalShares = ST_HYPE.totalShares() / ST_HYPE.balanceToShareDecimals();

        uint256 hypePrice = uint256(IEACAggregatorProxy(HYPE_USD_PRICE_FEED).latestAnswer());

        require(hypePrice > 0, "HYPE/USD price is 0");
        require(totalHype * PRECISION / totalShares <= uint256(type(int256).max), "wstHYPE/HYPE int256 overflow");

        // USD price of wstHYPE
        return IEACAggregatorProxy(HYPE_USD_PRICE_FEED).latestAnswer() * int256(totalHype * PRECISION / totalShares) / int256(PRECISION);
    }

    /// @notice Returns the latest round data
    function latestRoundData() external view returns (
        uint80 roundId,
        int256 answer,
        uint256 startedAt,
        uint256 updatedAt,
        uint80 answeredInRound
    ) {
        (
            roundId,
            ,  // unused price value
            startedAt,
            updatedAt,
            answeredInRound
        ) = AggregatorV3Interface(HYPE_USD_PRICE_FEED).latestRoundData();

        answer = this.latestAnswer();
        
        return (roundId, answer, startedAt, updatedAt, answeredInRound);
    }

    /// @notice Returns the decimals of the oracle price
    function decimals() external view returns (uint8) {
        return AggregatorV3Interface(HYPE_USD_PRICE_FEED).decimals();
    }

    /// @notice Returns the description of the oracle
    function description() external pure returns (string memory) {
        return "wstHYPE/USD Oracle";
    }

    /// @notice Version number of the oracle
    function version() external pure returns (uint256) {
        return 1;
    }

    /// @notice Returns data about a specific round
    function getRoundData(uint80 _roundId) external view returns (
        uint80 roundId,
        int256 answer,
        uint256 startedAt,
        uint256 updatedAt,
        uint80 answeredInRound
    ) {
        (
            roundId,
            ,  // unused price value
            startedAt,
            updatedAt,
            answeredInRound
        ) = AggregatorV3Interface(HYPE_USD_PRICE_FEED).getRoundData(_roundId);

        // Note: This returns the current wstHYPE price rather than historical data
        // as we cannot get historical stHYPE/HYPE ratios
        answer = this.latestAnswer();
        
        return (roundId, answer, startedAt, updatedAt, answeredInRound);
    }
}
