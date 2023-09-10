// SPDX-License-Identifier: CAL
pragma solidity ^0.8.18;

import {SignedContextV1} from "rain.interpreter/src/interface/IInterpreterCallerV2.sol";
import {Evaluable, EvaluableConfigV2} from "rain.interpreter/src/lib/caller/LibEvaluable.sol";

import {FlowERC1155IOV1, ERC1155SupplyChange} from "../IFlowERC1155V3.sol";

struct FlowERC1155ConfigV2 {
    string uri;
    EvaluableConfigV2 evaluableConfig;
    EvaluableConfigV2[] flowConfig;
}

interface IFlowERC1155V4 {
    event Initialize(address sender, FlowERC1155ConfigV2 config);

    function previewFlow(
        Evaluable calldata evaluable,
        uint256[] calldata callerContext,
        SignedContextV1[] calldata signedContexts
    ) external view returns (FlowERC1155IOV1 calldata);

    function flow(
        Evaluable calldata evaluable,
        uint256[] calldata callerContext,
        SignedContextV1[] calldata signedContexts
    ) external returns (FlowERC1155IOV1 calldata);
}
