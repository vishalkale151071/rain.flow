// SPDX-License-Identifier: CAL
pragma solidity =0.8.19;

import "forge-std/Test.sol";
import "lib/rain.interpreter/src/lib/op/LibAllStandardOpsNP.sol";
/// @title RainterpreterExternTest
/// Test suite for RainterpreterExtern.
contract GetBytesTest is Test {

    // function getBytes() public pure returns(bytes memory) {
    function testGetBytes() pure external {
        bytes memory authoringMeta = LibAllStandardOpsNP.authoringMeta();
        console2.log("Bytes : ");
        console2.logBytes(authoringMeta);
    }
}