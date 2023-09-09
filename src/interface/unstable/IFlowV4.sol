// SPDX-License-Identifier: CAL
pragma solidity ^0.8.18;

import "rain.interpreter/src/interface/IInterpreterCallerV2.sol";
import "rain.interpreter/src/lib/caller/LibEvaluable.sol";

import {FlowTransferV1} from "../IFlowV3.sol";

struct FlowConfigV2 {
    // https://github.com/ethereum/solidity/issues/13597
    EvaluableConfigV2 dummyConfig;
    EvaluableConfigV2[] config;
}

interface IFlowV4 {
    event Initialize(address sender, FlowConfigV2 config);

    function previewFlow(
        Evaluable calldata evaluable,
        uint256[] calldata callerContext,
        SignedContextV1[] calldata signedContexts
    ) external view returns (FlowTransferV1 calldata flowTransfer);

    function flow(
        Evaluable calldata evaluable,
        uint256[] calldata callerContext,
        SignedContextV1[] calldata signedContexts
    ) external returns (FlowTransferV1 calldata flowTransfer);
}
