// SPDX-License-Identifier: CAL
pragma solidity =0.8.18;

import "rain.interface.interpreter/LibContext.sol";
import "rain.interface.interpreter/LibEvaluable.sol";

struct FlowConfig {
    // https://github.com/ethereum/solidity/issues/13597
    EvaluableConfig dummyConfig;
    EvaluableConfig[] config;
}

interface IFlowV1 {
    event Initialize(address sender, FlowConfig config);

    function previewFlow(
        Evaluable memory evaluable_,
        uint256[] memory callerContext_,
        SignedContext[] memory signedContexts_
    ) external view;

    function flow(Evaluable memory evaluable_, uint256[] memory callerContext_, SignedContext[] memory signedContexts_)
        external
        payable;
}
