// SPDX-License-Identifier: CAL
pragma solidity ^0.8.18;

import "rain.interpreter/src/interface/IInterpreterCallerV2.sol";
import "rain.interpreter/src/lib/caller/LibEvaluable.sol";

import {
    FlowERC721IOV1,
    ERC721SupplyChange,
    FLOW_ERC721_TOKEN_URI_MIN_OUTPUTS,
    FLOW_ERC721_TOKEN_URI_MAX_OUTPUTS,
    FLOW_ERC721_HANDLE_TRANSFER_MIN_OUTPUTS,
    FLOW_ERC721_HANDLE_TRANSFER_MAX_OUTPUTS,
    FLOW_ERC721_TOKEN_URI_ENTRYPOINT,
    FLOW_ERC721_HANDLE_TRANSFER_ENTRYPOINT,
    FLOW_ERC721_MIN_FLOW_SENTINELS
} from "../IFlowERC721V3.sol";

import {RAIN_FLOW_SENTINEL} from "./IFlowV4.sol";

/// Thrown when burner of tokens is not the owner of tokens.
error BurnerNotOwner();

/// Initialization config.
/// @param name As per Open Zeppelin `ERC721Upgradeable`.
/// @param symbol As per Open Zeppelin `ERC721Upgradeable`.
/// @param baseURI As per Open Zeppelin `ERC721Upgradeable`.
/// @param evaluableConfig The `EvaluableConfigV2` to use to build the
/// `evaluable` that can be used to handle transfers and build token IDs for the
/// token URI.
/// @param flowConfig Initialization config for the `Evaluable`s that define the
/// flow behaviours outside self mints/burns.
struct FlowERC721ConfigV2 {
    string name;
    string symbol;
    string baseURI;
    EvaluableConfigV2 evaluableConfig;
    EvaluableConfigV2[] flowConfig;
}

/// @title IFlowERC721V4
/// Conceptually identical to `IFlowV4`, but the flow contract itself is an
/// ERC721 token. This means that ERC721 self mints and burns are included in the
/// stack that the flows must evaluate to. As stacks are processed by flow from
/// bottom to top, this means that the self mint/burn will be the last thing
/// evaluated, with mints at the bottom and burns next, followed by the flows.
///
/// As the flow is an ERC721 token it also includes an evaluation to be run on
/// every token transfer. This is the `handleTransfer` entrypoint. The return
/// stack of this evaluation is ignored, but reverts MUST be respected. This
/// allows expression authors to prevent transfers from occurring if they don't
/// want them to, by reverting within the expression.
///
/// The flow contract also includes an evaluation to be run on every token URI
/// request. This is the `tokenURI` entrypoint. The return value of this
/// evaluation is the token ID to use for the token URI. This entryoint is
/// optional, and if not provided the token URI will be the default Open Zeppelin
/// token URI logic.
///
/// Otherwise the flow contract is identical to `IFlowV4`.
interface IFlowERC721V4 {
    /// Contract has initialized.
    /// @param sender `msg.sender` initializing the contract (factory).
    /// @param config All initialized config.
    event Initialize(address sender, FlowERC721ConfigV2 config);

    /// As per `IFlowV4` but returns a `FlowERC721IOV1` instead of a
    /// `FlowTransferV1`.
    function stackToFlow(uint256[] memory stack) external pure returns (FlowERC721IOV1 memory flowERC721IO);

    /// As per `IFlowV4` but returns a `FlowERC721IOV1` instead of a
    /// `FlowTransferV1` and mints/burns itself as an ERC721 accordingly.
    /// @param evaluable The `Evaluable` to use to evaluate the flow.
    /// @param callerContext The caller context to use to evaluate the flow.
    /// @param signedContexts The signed contexts to use to evaluate the flow.
    /// @return flowERC721IO The `FlowERC721IOV1` representing all token
    /// mint/burns and transfers that occurred during the flow.
    function flow(
        Evaluable calldata evaluable,
        uint256[] calldata callerContext,
        SignedContextV1[] calldata signedContexts
    ) external returns (FlowERC721IOV1 calldata flowERC721IO);
}
