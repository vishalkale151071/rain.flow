// SPDX-License-Identifier: CAL
pragma solidity =0.8.19;

import "forge-std/Test.sol";

import {IFlowV4, RAIN_FLOW_SENTINEL} from "src/interface/unstable/IFlowV4.sol";
import {Sentinel} from "rain.solmem/lib/LibStackSentinel.sol";

contract IFlowV4Test is Test {
    function testSentinelValue() external {
        assertEq(
            0xfea74d0c9bf4a3c28f0dd0674db22a3d7f8bf259c56af19f4ac1e735b156974f, Sentinel.unwrap(RAIN_FLOW_SENTINEL)
        );
    }
}
