// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {RateOracle} from "../src/oracle/RateOracle.sol";
import {MarketFactory} from "../src/swap/MarketFactory.sol";
import {SwapMarket} from "../src/swap/SwapMarket.sol";
import {MarketParams} from "../src/interfaces/IMarketParams.sol";
import {YieldCurve} from "../src/loans/YieldCurve.sol";
import {LoanOriginator} from "../src/loans/LoanOriginator.sol";
import {MockERC20} from "../test/mocks/MockERC20.sol";

contract Deploy is Script {
    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        address me = vm.addr(pk);

        vm.startBroadcast(pk);
        MockERC20 token = new MockERC20();
        RateOracle oracle = new RateOracle(me, 3650 days);
        MarketFactory factory = new MarketFactory();

        MarketParams memory p = MarketParams({
            rateOracle: address(oracle),
            asset: address(token),
            underlyingRate: address(token),
            tenor: 730 days,
            initialMarginBps: 1000,
            maintenanceMarginBps: 500,
            initialFixedRate: 0.07e18,
            baseScalar: 100e18,
            liquidityFeeBps: 10
        });
        address market = factory.createMarket(p);

        YieldCurve.CurvePoint[] memory pts = new YieldCurve.CurvePoint[](2);
        pts[0] = YieldCurve.CurvePoint(365 days, 0.07e18);
        pts[1] = YieldCurve.CurvePoint(730 days, 0.075e18);
        YieldCurve curve = new YieldCurve(pts);

        LoanOriginator originator = new LoanOriginator(address(curve), market, address(token));

        token.mint(me, 2_000_000e18);
        oracle.updateIndex(address(token), 0.07e18);
        address marginAddr = address(SwapMarket(market).margin());
        IERC20(address(token)).approve(marginAddr, type(uint256).max);
        SwapMarket(market).provideLiquidity(500_000e18);
        IERC20(address(token)).approve(address(originator), type(uint256).max);
        originator.fund(200_000e18);
        vm.stopBroadcast();

        console2.log("TOKEN=%s", address(token));
        console2.log("ORACLE=%s", address(oracle));
        console2.log("FACTORY=%s", address(factory));
        console2.log("MARKET=%s", market);
        console2.log("CURVE=%s", address(curve));
        console2.log("ORIGINATOR=%s", address(originator));
    }
}
