// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {LogitCurve} from "../libraries/LogitCurve.sol";

contract RateAMM {
    address public immutable market;
    address public immutable underlyingRate;
    uint256 public immutable tenor;
    uint256 public immutable inceptionTime;
    uint256 public immutable baseScalar;
    uint256 public immutable liquidityFeeBps;

    uint256 public lastImpliedRate;
    int256 public netFixedExposure;
    uint256 public totalLiquidity;

    error NotMarket();

    event LiquidityChanged(uint256 totalLiquidity);
    event Traded(bool payFixed, uint256 notional, int256 netFixedExposure, uint256 lastImpliedRate);

    constructor(
        address _underlyingRate,
        uint256 _tenor,
        uint256 _initialFixedRate,
        uint256 _baseScalar,
        uint256 _liquidityFeeBps
    ) {
        market = msg.sender;
        underlyingRate = _underlyingRate;
        tenor = _tenor;
        inceptionTime = block.timestamp;
        lastImpliedRate = _initialFixedRate;
        baseScalar = _baseScalar == 0 ? 100e18 : _baseScalar;
        liquidityFeeBps = _liquidityFeeBps;
    }

    modifier onlyMarket() {
        if (msg.sender != market) revert NotMarket();
        _;
    }

    function maturity() public view returns (uint256) {
        return inceptionTime + tenor;
    }

    function timeToMaturity() public view returns (uint256) {
        uint256 m = maturity();
        return m > block.timestamp ? m - block.timestamp : 0;
    }

    function setLiquidity(uint256 newTotal) external onlyMarket {
        totalLiquidity = newTotal;
        emit LiquidityChanged(newTotal);
    }

    function _mid(int256 newExposure) internal view returns (uint256) {
        uint256 scalar = LogitCurve.scalarAt(baseScalar, tenor, timeToMaturity());
        return LogitCurve.midRate(netFixedExposure, newExposure, totalLiquidity, lastImpliedRate, scalar);
    }

    function quoteFixedRate(bool payFixed, uint256 notional) public view returns (uint256) {
        int256 signed = payFixed ? int256(notional) : -int256(notional);
        uint256 mid = _mid(netFixedExposure + signed);
        uint256 fee = (mid * liquidityFeeBps) / 10_000;
        if (payFixed) return mid + fee;
        return mid > fee ? mid - fee : 0;
    }

    function _applyTrade(int256 delta) internal {
        int256 newExposure = netFixedExposure + delta;
        uint256 newMid = _mid(newExposure);
        netFixedExposure = newExposure;
        lastImpliedRate = newMid;
    }

    function onOpen(bool payFixed, uint256 notional) external onlyMarket {
        int256 signed = payFixed ? int256(notional) : -int256(notional);
        _applyTrade(signed);
        emit Traded(payFixed, notional, netFixedExposure, lastImpliedRate);
    }

    function onClose(bool wasPayFixed, uint256 notional) external onlyMarket {
        int256 signed = wasPayFixed ? int256(notional) : -int256(notional);
        _applyTrade(-signed);
        emit Traded(!wasPayFixed, notional, netFixedExposure, lastImpliedRate);
    }
}
