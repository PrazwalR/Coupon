// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

struct MarketParams {
    address rateOracle;
    address asset;
    address underlyingRate;
    uint256 tenor;
    uint256 initialMarginBps;
    uint256 maintenanceMarginBps;
    uint256 initialFixedRate;
    uint256 baseScalar;
    uint256 liquidityFeeBps;
}
