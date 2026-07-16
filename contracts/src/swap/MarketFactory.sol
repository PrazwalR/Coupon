// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {MarketParams} from "../interfaces/IMarketParams.sol";
import {SwapMarket} from "./SwapMarket.sol";

contract MarketFactory {
    mapping(bytes32 => address) public markets;
    address[] public allMarkets;

    error MarketExists();

    event MarketCreated(bytes32 indexed marketId, address market, MarketParams params);

    function marketId(MarketParams calldata p) public pure returns (bytes32) {
        return keccak256(
            abi.encode(p.rateOracle, p.asset, p.underlyingRate, p.tenor, p.initialMarginBps)
        );
    }

    function createMarket(MarketParams calldata p) external returns (address market) {
        bytes32 id = marketId(p);
        if (markets[id] != address(0)) revert MarketExists();
        market = address(new SwapMarket(p));
        markets[id] = market;
        allMarkets.push(market);
        emit MarketCreated(id, market, p);
    }

    function marketCount() external view returns (uint256) {
        return allMarkets.length;
    }
}
