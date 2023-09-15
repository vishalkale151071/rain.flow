// SPDX-License-Identifier: CAL
pragma solidity ^0.8.18;

import {SignedContextV1} from "rain.interpreter/src/interface/IInterpreterCallerV2.sol";
import {EvaluableConfigV2} from "rain.interpreter/src/lib/caller/LibEvaluable.sol";

import "./IFlowV3.sol";

/// @dev Entrypont of the `handleTransfer` evaluation.
SourceIndex constant FLOW_ERC1155_HANDLE_TRANSFER_ENTRYPOINT = SourceIndex.wrap(0);

/// @dev Minimum number of outputs of the `handleTransfer` evaluation.
/// This is 0 because the return stack is ignored.
uint256 constant FLOW_ERC1155_HANDLE_TRANSFER_MIN_OUTPUTS = 0;

/// @dev Maximum number of outputs of the `handleTransfer` evaluation.
/// This is 0 because the return stack is ignored.
uint16 constant FLOW_ERC1155_HANDLE_TRANSFER_MAX_OUTPUTS = 0;

/// @dev Minimum number of sentinels required by `FlowERC1155`.
/// This is 2 more than the minimum required by `FlowCommon` because the
/// mints and burns are included in the stack.
uint256 constant FLOW_ERC1155_MIN_FLOW_SENTINELS = MIN_FLOW_SENTINELS + 2;

/// @dev v3 of `FlowERC1155` expected a sentinel different to
/// `RAIN_FLOW_SENTINEL`, but this was generally more confusing than helpful.
Sentinel constant RAIN_FLOW_ERC1155_SENTINEL =
    Sentinel.wrap(uint256(keccak256(bytes("RAIN_FLOW_ERC1155_SENTINEL")) | SENTINEL_HIGH_BITS));

/// Initializer config.
/// @param uri As per Open Zeppelin `ERC1155Upgradeable`.
/// @param evaluableConfig The `EvaluableConfigV2` to use to build the
/// `evaluable` that can be used to handle transfers.
/// @param flowConfig Constructor config for the `Evaluable`s that define the
/// flow behaviours including self mints/burns.
struct FlowERC1155Config {
    string uri;
    EvaluableConfig evaluableConfig;
    EvaluableConfig[] flowConfig;
}

/// Represents a single mint or burn of a single ERC1155 token. Whether this is
/// a mint or burn must be implied by the context.
/// @param account The address the token is being minted/burned to/from.
/// @param id The id of the token being minted/burned.
/// @param amount The amount of the token being minted/burned.
struct ERC1155SupplyChange {
    address account;
    uint256 id;
    uint256 amount;
}

/// Represents a set of ERC1155 transfers, including self mints/burns.
/// @param mints The mints that occurred.
/// @param burns The burns that occurred.
/// @param flow The transfers that occured.
struct FlowERC1155IOV1 {
    ERC1155SupplyChange[] mints;
    ERC1155SupplyChange[] burns;
    FlowTransferV1 flow;
}

/// @title IFlowERC1155V3
/// Conceptually identical to `IFlowV3`, but the flow contract itself is an
/// ERC1155 token. This means that ERC1155 self mints and burns are included in
/// the stack that the flows must evaluate to. As stacks are processed by flow
/// from bottom to top, this means that the self mint/burn will be the last thing
/// evaluated, with mints at the bottom and burns next, followed by the flows.
///
/// As the flow is an ERC1155 token it also includes an evaluation to be run on
/// every token transfer. This is the `handleTransfer` entrypoint. The return
/// stack of this evaluation is ignored, but reverts MUST be respected. This
/// allows expression authors to prevent transfers from occurring if they don't
/// want them to, by reverting within the expression.
///
/// Otherwise the flow contract is identical to `IFlowV3`.
interface IFlowERC1155V3 {
    /// Contract has initialized.
    event Initialize(address sender, FlowERC1155Config config);

    /// As per `IFlowV3` but returns a `FlowERC1155IOV1` instead of a
    /// `FlowTransferV1`.
    /// @param evaluable The `Evaluable` that is flowing.
    /// @param callerContext The context of the caller.
    /// @param signedContexts The signed contexts of the caller.
    /// @return flowERC1155IO The `FlowERC1155IOV1` that occurred.
    function previewFlow(
        Evaluable calldata evaluable,
        uint256[] calldata callerContext,
        SignedContextV1[] calldata signedContexts
    ) external view returns (FlowERC1155IOV1 calldata flowERC1155IO);

    /// As per `IFlowV3` but returns a `FlowERC1155IOV1` instead of a
    /// `FlowTransferV1` and mints/burns itself as an ERC1155 accordingly.
    /// @param evaluable The `Evaluable` that is flowing.
    /// @param callerContext The context of the caller.
    /// @param signedContexts The signed contexts of the caller.
    /// @return flowERC1155IO The `FlowERC1155IOV1` that occurred.
    function flow(
        Evaluable calldata evaluable,
        uint256[] calldata callerContext,
        SignedContextV1[] calldata signedContexts
    ) external returns (FlowERC1155IOV1 calldata flowERC1155IO);
}
