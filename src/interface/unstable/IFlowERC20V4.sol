// SPDX-License-Identifier: CAL
pragma solidity ^0.8.18;

import {SignedContextV1} from "rain.interpreter/src/interface/IInterpreterCallerV2.sol";
import {Evaluable, EvaluableConfigV2} from "rain.interpreter/src/lib/caller/LibEvaluable.sol";
import {Sentinel} from "rain.solmem/lib/LibStackSentinel.sol";
import {
    FlowERC20IOV1,
    ERC20SupplyChange,
    FLOW_ERC20_HANDLE_TRANSFER_ENTRYPOINT,
    FLOW_ERC20_HANDLE_TRANSFER_MIN_OUTPUTS,
    FLOW_ERC20_HANDLE_TRANSFER_MAX_OUTPUTS,
    FLOW_ERC20_MIN_FLOW_SENTINELS
} from "../IFlowERC20V3.sol";
import {RAIN_FLOW_SENTINEL} from "./IFlowV4.sol";

/// Initialization config.
/// @param name As per Open Zeppelin `ERC20Upgradeable`.
/// @param symbol As per Open Zeppelin `ERC20Upgradeable`.
/// @param evaluableConfig The `EvaluableConfigV2` to use to build the
/// `evaluable` that can be used to evaluate `handleTransfer`.
/// @param flowConfig The `EvaluableConfigV2[]` to use to build the
/// `evaluable`s for all the flows, including self minting and burning.
struct FlowERC20ConfigV2 {
    string name;
    string symbol;
    EvaluableConfigV2 evaluableConfig;
    EvaluableConfigV2[] flowConfig;
}

/// @title IFlowERC20V4
/// Conceptually identical to `IFlowV4`, but the flow contract itself is an
/// ERC20 token. This means that ERC20 self mints and burns are included in the
/// stack that the flows must evaluate to. As stacks are processed by flow from
/// bottom to top, this means that the self mint/burn will be the last thing
/// evaluated, with mints at the bottom and burns next, followed by the flows.
///
/// As the flow is an ERC20 token it also includes an evaluation to be run on
/// every token transfer. This is the `handleTransfer` entrypoint. The return
/// stack of this evaluation is ignored, but reverts MUST be respected. This
/// allows expression authors to prevent transfers from occurring if they don't
/// want them to, by reverting within the expression.
///
/// Otherwise the flow contract is identical to `IFlowV4`.
interface IFlowERC20V4 {
    /// Contract has initialized.
    /// @param sender `msg.sender` initializing the contract (factory).
    /// @param config All initialized config.
    event Initialize(address sender, FlowERC20ConfigV2 config);

    /// As per `IFlowV4` but returns a `FlowERC20IOV1` instead of a
    /// `FlowTransferV1`.
    /// @param stack The stack to convert to a `FlowERC20IOV1`.
    /// @return flowERC20IO The `FlowERC20IOV1` representation of the stack.
    function stackToFlow(uint256[] memory stack) external pure returns (FlowERC20IOV1 memory flowERC20IO);

    /// As per `IFlowV4` but returns a `FlowERC20IOV1` instead of a
    /// `FlowTransferV1` and mints/burns itself as an ERC20 accordingly.
    /// @param evaluable The `Evaluable` to use to evaluate the flow.
    /// @param callerContext The caller context to use to evaluate the flow.
    /// @param signedContexts The signed contexts to use to evaluate the flow.
    /// @return flowERC20IO The `FlowERC20IOV1` representing all token mint/burns
    /// and transfers that occurred during the flow.
    function flow(
        Evaluable calldata evaluable,
        uint256[] calldata callerContext,
        SignedContextV1[] calldata signedContexts
    ) external returns (FlowERC20IOV1 calldata flowERC20IO);
}
