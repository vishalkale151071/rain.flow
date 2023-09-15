// SPDX-License-Identifier: CAL
pragma solidity ^0.8.18;

import "rain.interpreter/src/interface/IInterpreterCallerV2.sol";
import "rain.interpreter/src/lib/caller/LibEvaluable.sol";

import "./IFlowV3.sol";

/// @dev Entrypont of the `handleTransfer` evaluation.
SourceIndex constant FLOW_ERC721_HANDLE_TRANSFER_ENTRYPOINT = SourceIndex.wrap(0);
/// @dev Entrypont of the `tokenURI` evaluation.
SourceIndex constant FLOW_ERC721_TOKEN_URI_ENTRYPOINT = SourceIndex.wrap(1);

/// @dev Minimum number of outputs of the `handleTransfer` evaluation.
/// This is 0 because the return stack is ignored.
uint256 constant FLOW_ERC721_HANDLE_TRANSFER_MIN_OUTPUTS = 0;
/// @dev Minimum number of outputs of the `tokenURI` evaluation.
/// This is 1 because we can only handle a single token ID value.
uint256 constant FLOW_ERC721_TOKEN_URI_MIN_OUTPUTS = 1;

/// @dev Maximum number of outputs of the `handleTransfer` evaluation.
/// This is 0 because the return stack is ignored.
uint16 constant FLOW_ERC721_HANDLE_TRANSFER_MAX_OUTPUTS = 0;
/// @dev Maximum number of outputs of the `tokenURI` evaluation.
/// This is 1 because we can only handle a single token ID value.
uint16 constant FLOW_ERC721_TOKEN_URI_MAX_OUTPUTS = 1;

/// @dev v3 of `FlowERC721` expected a sentinel different to
/// `RAIN_FLOW_SENTINEL`, but this was generally more confusing than helpful.
Sentinel constant RAIN_FLOW_ERC721_SENTINEL =
    Sentinel.wrap(uint256(keccak256(bytes("RAIN_FLOW_ERC721_SENTINEL")) | SENTINEL_HIGH_BITS));

/// @dev Minimum number of sentinels required by `FlowERC721`.
/// This is 2 more than the minimum required by `FlowCommon` because the
/// mints and burns are included in the stack.
uint256 constant FLOW_ERC721_MIN_FLOW_SENTINELS = MIN_FLOW_SENTINELS + 2;

/// Initializer config.
/// @param name As per Open Zeppelin `ERC721Upgradeable`.
/// @param symbol As per Open Zeppelin `ERC721Upgradeable`.
/// @param baseURI As per Open Zeppelin `ERC721Upgradeable`.
/// @param evaluableConfig The `EvaluableConfigV2` to use to build the
/// `evaluable` that can be used to handle transfers and token URIs. The token
/// URI entrypoint is optional.
/// @param flowConfig Constructor config for the `Evaluable`s that define the
/// flow behaviours including self mints/burns.
struct FlowERC721Config {
    string name;
    string symbol;
    string baseURI;
    EvaluableConfig evaluableConfig;
    EvaluableConfig[] flowConfig;
}

/// Represents a single mint or burn of a single ERC721 token. Whether this is
/// a mint or burn must be implied by the context.
/// @param account The address the token is being minted/burned to/from.
/// @param id The id of the token being minted/burned.
struct ERC721SupplyChange {
    address account;
    uint256 id;
}

/// Represents a set of ERC721 transfers, including self mints/burns.
/// @param mints The mints that occurred.
/// @param burns The burns that occurred.
/// @param flow The transfers that occured.
struct FlowERC721IOV1 {
    ERC721SupplyChange[] mints;
    ERC721SupplyChange[] burns;
    FlowTransferV1 flow;
}

/// @title IFlowERC721V3
/// Conceptually identical to `IFlowV3`, but the flow contract itself is an
/// ERC721 token. This means that ERC721 self mints and burns are included in
/// the stack.
///
/// As the flow is an ERC721 token, there are two entrypoints in addition to
/// the flows:
/// - `handleTransfer` is called when the flow is transferred.
/// - `tokenURI` is called when the token URI is requested.
///
/// The `handleTransfer` entrypoint is mandatory, but the `tokenURI` entrypoint
/// is optional. If the `tokenURI` entrypoint is not provided, the default
/// Open Zeppelin implementation will be used.
///
/// The `handleTransfer` entrypoint may be used to restrict transfers of the
/// flow token. For example, it may be used to restrict transfers to only
/// occur when the flow is in a certain state.
///
/// The `tokenURI` entrypoint may be used to provide a custom token ID to build
/// a token URI for the flow token.
///
/// Otherwise the flow contract behaves identically to `IFlowV3`.
interface IFlowERC721V3 {
    /// Contract has initialized.
    /// @param sender `msg.sender` initializing the contract (factory).
    /// @param config All initialized config.
    event Initialize(address sender, FlowERC721Config config);

    /// As per `IFlowV3` but returns a `FlowERC721IOV1` instead of a
    /// `FlowTransferV1`.
    /// @param evaluable The `Evaluable` that is flowing.
    /// @param callerContext The context of the caller.
    /// @param signedContexts The signed contexts of the caller.
    /// @return flowERC721IO The `FlowERC721IOV1` that would occur if the flow
    /// was executed.
    function previewFlow(
        Evaluable calldata evaluable,
        uint256[] calldata callerContext,
        SignedContextV1[] calldata signedContexts
    ) external view returns (FlowERC721IOV1 calldata flowERC721IO);

    /// As per `IFlowV3` but returns a `FlowERC721IOV1` instead of a
    /// `FlowTransferV1` and mints/burns itself as an ERC721 accordingly.
    /// @param evaluable The `Evaluable` that is flowing.
    /// @param callerContext The context of the caller.
    /// @param signedContexts The signed contexts of the caller.
    /// @return flowERC721IO The `FlowERC721IOV1` that occurred.
    function flow(
        Evaluable calldata evaluable,
        uint256[] calldata callerContext,
        SignedContextV1[] calldata signedContexts
    ) external returns (FlowERC721IOV1 calldata flowERC721IO);
}
