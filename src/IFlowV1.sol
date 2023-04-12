// SPDX-License-Identifier: CAL
pragma solidity =0.8.18;

interface IFlowV1 {
    function previewFlow(
        Evaluable memory evaluable_,
        uint256[] memory callerContext_,
        SignedContext[] memory signedContexts_
    ) external view virtual;

    function flow(
        Evaluable memory evaluable_,
        uint256[] memory callerContext_,
        SignedContext[] memory signedContexts_
    ) external payable;
}