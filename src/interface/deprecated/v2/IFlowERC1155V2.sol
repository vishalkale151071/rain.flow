// SPDX-License-Identifier: CAL
pragma solidity ^0.8.18;

import "rain.interpreter/interface/IInterpreterCallerV2.sol";
import "rain.interpreter/lib/caller/LibEvaluable.sol";

import "./IFlowV2.sol";

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

struct FlowERC1155IO {
    ERC1155SupplyChange[] mints;
    ERC1155SupplyChange[] burns;
    FlowTransfer flow;
}

/// @title IFlowERC1155V2
interface IFlowERC1155V2 {
    event Initialize(address sender, FlowERC1155Config config);

    function previewFlow(
        Evaluable calldata evaluable,
        uint256[] calldata callerContext,
        SignedContextV1[] calldata signedContexts
    ) external view returns (FlowERC1155IO calldata);

    function flow(
        Evaluable calldata evaluable,
        uint256[] calldata callerContext,
        SignedContextV1[] calldata signedContexts
    ) external payable returns (FlowERC1155IO calldata);
}
