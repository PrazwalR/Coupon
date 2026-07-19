// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {MarketFactory} from "../../src/swap/MarketFactory.sol";
import {MarketParams} from "../../src/interfaces/IMarketParams.sol";

contract FactoryEdgeTest is Test {
    MarketFactory factory;

    function setUp() public {
        factory = new MarketFactory();
    }

    function _params(uint256 tenor) internal pure returns (MarketParams memory) {
        return MarketParams({
            rateOracle: address(0x1),
            asset: address(0x2),
            underlyingRate: address(0x2),
            tenor: tenor,
            initialMarginBps: 1000,
            maintenanceMarginBps: 500,
            initialFixedRate: 0.07e18,
            baseScalar: 100e18,
            liquidityFeeBps: 10
        });
    }

    function test_duplicate_market_reverts() public {
        factory.createMarket(_params(365 days));
        vm.expectRevert(MarketFactory.MarketExists.selector);
        factory.createMarket(_params(365 days));
    }

    function test_different_tenor_is_distinct_market() public {
        factory.createMarket(_params(365 days));
        factory.createMarket(_params(730 days));
        assertEq(factory.marketCount(), 2);
    }
}
