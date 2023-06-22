// SPDX-License-Identifier: CAL
pragma solidity ^0.8.18;

import "rain.interpreter/interface/deprecated/IInterpreterCallerV1.sol";
import "rain.interpreter/lib/LibEvaluable.sol";

import "./IFlowV1.sol";

/// Constructor config.
/// @param Constructor config for the ERC721 token minted according to flow
/// schedule in `flow`.
/// @param Constructor config for the `ImmutableSource` that defines the
/// emissions schedule for claiming.
struct FlowERC721Config {
    string name;
    string symbol;
    string baseURI;
    EvaluableConfig evaluableConfig;
    EvaluableConfig[] flowConfig;
}

struct ERC721SupplyChange {
    address account;
    uint256 id;
}

struct FlowERC721IO {
    ERC721SupplyChange[] mints;
    ERC721SupplyChange[] burns;
    FlowTransfer flow;
}

/// @title IFlowERC721V1
interface IFlowERC721V1 {
    /// Contract has initialized.
    /// @param sender `msg.sender` initializing the contract (factory).
    /// @param config All initialized config.
    event Initialize(address sender, FlowERC721Config config);

    function previewFlow(
        Evaluable calldata evaluable,
        uint256[] calldata callerContext,
        SignedContext[] calldata signedContexts
    ) external view returns (FlowERC721IO calldata);

    function flow(
        Evaluable calldata evaluable,
        uint256[] calldata callerContext,
        SignedContext[] calldata signedContexts
    ) external payable returns (FlowERC721IO calldata);
}
