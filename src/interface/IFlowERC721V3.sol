// SPDX-License-Identifier: CAL
pragma solidity ^0.8.18;

import "rain.interpreter/interface/IInterpreterCallerV2.sol";
import "rain.interpreter/lib/LibEvaluable.sol";

import "./IFlowV3.sol";

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

struct FlowERC721IOV1 {
    ERC721SupplyChange[] mints;
    ERC721SupplyChange[] burns;
    FlowTransferV1 flow;
}

/// @title IFlowERC721V3
interface IFlowERC721V3 {
    /// Contract has initialized.
    /// @param sender `msg.sender` initializing the contract (factory).
    /// @param config All initialized config.
    event Initialize(address sender, FlowERC721Config config);

    function previewFlow(
        Evaluable calldata evaluable,
        uint256[] calldata callerContext,
        SignedContextV1[] calldata signedContexts
    ) external view returns (FlowERC721IOV1 calldata);

    function flow(
        Evaluable calldata evaluable,
        uint256[] calldata callerContext,
        SignedContextV1[] calldata signedContexts
    ) external returns (FlowERC721IOV1 calldata);
}
