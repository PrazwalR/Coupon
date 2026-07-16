// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IRateOracle} from "../interfaces/IRateOracle.sol";

contract RateOracle is IRateOracle {
    struct Observation {
        uint256 rate;
        uint256 accumulator;
        uint256 timestamp;
    }

    mapping(address => Observation) public latest;
    mapping(address => bool) public isPublisher;

    address public immutable governance;
    uint256 public immutable maxStaleness;

    error NotPublisher();
    error NotGovernance();
    error StaleUpdate();
    error NoData();
    error Stale();
    error BadInput();

    event IndexUpdated(address indexed asset, uint256 rate, uint256 accumulator, uint256 timestamp);
    event PublisherSet(address indexed publisher, bool allowed);

    constructor(address publisher, uint256 _maxStaleness) {
        governance = msg.sender;
        isPublisher[publisher] = true;
        maxStaleness = _maxStaleness;
        emit PublisherSet(publisher, true);
    }

    modifier onlyGovernance() {
        if (msg.sender != governance) revert NotGovernance();
        _;
    }

    function setPublisher(address publisher, bool allowed) external onlyGovernance {
        isPublisher[publisher] = allowed;
        emit PublisherSet(publisher, allowed);
    }

    function updateIndex(address asset, uint256 newRate) external {
        if (!isPublisher[msg.sender]) revert NotPublisher();

        Observation memory prev = latest[asset];
        uint256 nowTs = block.timestamp;
        uint256 newAccumulator;

        if (prev.timestamp == 0) {
            newAccumulator = 1e18;
        } else {
            if (nowTs <= prev.timestamp) revert StaleUpdate();
            uint256 dt = nowTs - prev.timestamp;
            uint256 growth = 1e18 + (prev.rate * dt) / 365 days;
            newAccumulator = (prev.accumulator * growth) / 1e18;
        }

        latest[asset] = Observation({rate: newRate, accumulator: newAccumulator, timestamp: nowTs});
        emit IndexUpdated(asset, newRate, newAccumulator, nowTs);
    }

    function _fresh(address asset) internal view returns (Observation memory o) {
        o = latest[asset];
        if (o.timestamp == 0) revert NoData();
        if (block.timestamp - o.timestamp > maxStaleness) revert Stale();
    }

    function getRate(address asset) external view returns (uint256) {
        return _fresh(asset).rate;
    }

    function currentAccumulator(address asset) external view returns (uint256) {
        return _fresh(asset).accumulator;
    }

    function floatingReturn(address asset, uint256 accStart) external view returns (uint256) {
        if (accStart == 0) revert BadInput();
        Observation memory o = _fresh(asset);
        return (o.accumulator * 1e18) / accStart - 1e18;
    }
}
