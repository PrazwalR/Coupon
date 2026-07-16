// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IRateOracle {
    function getRate(address asset) external view returns (uint256);

    function currentAccumulator(address asset) external view returns (uint256);

    function floatingReturn(address asset, uint256 accStart) external view returns (uint256);
}
