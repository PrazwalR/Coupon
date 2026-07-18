// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract YieldCurve {
    struct CurvePoint {
        uint256 tenor;
        uint256 fixedRate;
    }

    CurvePoint[] public points;
    address public immutable governance;

    error NotGovernance();
    error NoPoints();
    error Unsorted();
    error BadIndex();

    event PointSet(uint256 index, uint256 tenor, uint256 fixedRate);

    constructor(CurvePoint[] memory pts) {
        governance = msg.sender;
        if (pts.length == 0) revert NoPoints();
        for (uint256 i = 0; i < pts.length; i++) {
            if (i > 0 && pts[i].tenor <= pts[i - 1].tenor) revert Unsorted();
            points.push(pts[i]);
        }
    }

    modifier onlyGovernance() {
        if (msg.sender != governance) revert NotGovernance();
        _;
    }

    function numPoints() external view returns (uint256) {
        return points.length;
    }

    function rateForTenor(uint256 tenor) public view returns (uint256) {
        uint256 n = points.length;
        if (tenor <= points[0].tenor) return points[0].fixedRate;
        if (tenor >= points[n - 1].tenor) return points[n - 1].fixedRate;

        for (uint256 i = 0; i < n - 1; i++) {
            if (tenor >= points[i].tenor && tenor <= points[i + 1].tenor) {
                uint256 t0 = points[i].tenor;
                uint256 t1 = points[i + 1].tenor;
                uint256 r0 = points[i].fixedRate;
                uint256 r1 = points[i + 1].fixedRate;
                if (r1 >= r0) {
                    return r0 + ((r1 - r0) * (tenor - t0)) / (t1 - t0);
                }
                return r0 - ((r0 - r1) * (tenor - t0)) / (t1 - t0);
            }
        }
        revert BadIndex();
    }

    function setPoint(uint256 index, uint256 fixedRate) external onlyGovernance {
        if (index >= points.length) revert BadIndex();
        points[index].fixedRate = fixedRate;
        emit PointSet(index, points[index].tenor, fixedRate);
    }

    function addPoint(uint256 tenor, uint256 fixedRate) external onlyGovernance {
        if (tenor <= points[points.length - 1].tenor) revert Unsorted();
        points.push(CurvePoint({tenor: tenor, fixedRate: fixedRate}));
        emit PointSet(points.length - 1, tenor, fixedRate);
    }
}
