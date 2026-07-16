// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {RateOracle} from "../../src/oracle/RateOracle.sol";

contract OracleHandler is Test {
    RateOracle public oracle;
    address public constant ASSET = address(0xA55E7);
    bool public everDecreased;

    constructor() {
        oracle = new RateOracle(address(this), 1e30);
    }

    function publish(uint256 rate, uint256 dt) public {
        rate = bound(rate, 0, 1e18);
        dt = bound(dt, 1, 30 days);
        (, uint256 oldAcc,) = oracle.latest(ASSET);
        vm.warp(block.timestamp + dt);
        oracle.updateIndex(ASSET, rate);
        (, uint256 newAcc,) = oracle.latest(ASSET);
        if (newAcc < oldAcc) everDecreased = true;
    }
}

contract OracleInvariant is Test {
    OracleHandler handler;

    function setUp() public {
        vm.warp(1_000_000);
        handler = new OracleHandler();
        targetContract(address(handler));
    }

    function invariant_accumulator_monotonic() public view {
        assertFalse(handler.everDecreased());
    }
}
