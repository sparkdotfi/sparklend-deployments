// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import {IFHYPE} from "src/contracts/oracle/interfaces/IFHYPE.sol";
import {IPoolAddressesProvider} from "@aave/core-v3/contracts/interfaces/IPoolAddressesProvider.sol";
import {IPriceOracleGetter} from "@aave/core-v3/contracts/interfaces/IPriceOracleGetter.sol";
import {AggregatorV3Interface} from "src/contracts/oracle/interfaces/AggregatorV3Interface.sol";
import {IEACAggregatorProxy} from "aave-v3-periphery/misc/interfaces/IEACAggregatorProxy.sol";

/**
 * @title fHYPEOracle
 * @author HypurrFi
 * @notice Oracle for fHYPE token
 * Price is calculated by:
 * 1. Getting HYPE/USD price from Pyth
 * 2. Getting the fHYPE/HYPE ratio using getExchangeRate()
 * Final price = (HYPE/fHYPE) * (HYPE/USD price)
 */
contract fHYPEOracle is AggregatorV3Interface {
    address public constant HYPE_USD_PRICE_FEED = 0x1d0E4EA616A749c1620118F7d97c111e8ec36E8b;
    IFHYPE public constant F_HYPE = IFHYPE(0x34a70Db6c0E3d5f93d7026fa6dCd6e11adFd56C5 );
    uint256 public constant PRECISION = 1e18;

    struct LatestAnswerLocals {
        int256 hypeUsdPrice;
        uint256 hypePerFhype;
        uint256 fHypeUsdPrice;
    }

    /**
     * @notice Get the price of fHYPE in the base currency (ETH)
     * @return The price of fHYPE in the base currency (ETH)
     */
    function latestAnswer() external view returns (int256) {
        LatestAnswerLocals memory locals;

        locals.hypePerFhype = F_HYPE.getExchangeRate();

        locals.hypeUsdPrice = IEACAggregatorProxy(HYPE_USD_PRICE_FEED).latestAnswer();

        require(locals.hypeUsdPrice > 0, "HYPE/USD price is not positive");

        locals.fHypeUsdPrice = locals.hypePerFhype * uint256(locals.hypeUsdPrice) / PRECISION;

        noInt256Overflow(locals.fHypeUsdPrice, "fHYPE USD price int256 overflow");

        // USD price of fHYPE
        return int256(locals.fHypeUsdPrice);
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
        return "fHYPE/USD Oracle";
    }

    /// @notice Version number of the oracle
    function version() external pure returns (uint256) {
        return 1;
    }

    function getRoundData(uint80) external pure returns (
        uint80 roundId,
        int256 answer,
        uint256 startedAt,
        uint256 updatedAt,
        uint80 answeredInRound
    ) { 
        require(false, "Not implemented; No historical data for fHYPE/HYPE exchange rate");
        return (0, 0, 0, 0, 0);
    }

    function noInt256Overflow(uint256 a, string memory errorMessage) internal pure {
        require(a <= uint256(type(int256).max), errorMessage);
    }
}
