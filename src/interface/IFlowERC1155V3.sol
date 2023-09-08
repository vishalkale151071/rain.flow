// SPDX-License-Identifier: CAL
pragma solidity ^0.8.18;

import "rain.interpreter/src/interface/IInterpreterCallerV2.sol";
import "rain.interpreter/src/lib/caller/LibEvaluable.sol";

import "./IFlowV3.sol";

struct FlowERC1155Config {
    string uri;
    EvaluableConfig evaluableConfig;
    EvaluableConfig[] flowConfig;
}

struct ERC1155SupplyChange {
    address account;
    uint256 id;
    uint256 amount;
}

struct FlowERC1155IOV1 {
    ERC1155SupplyChange[] mints;
    ERC1155SupplyChange[] burns;
    FlowTransferV1 flow;
}

/// @title IFlowERC1155V3
interface IFlowERC1155V3 {
    event Initialize(address sender, FlowERC1155Config config);

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
