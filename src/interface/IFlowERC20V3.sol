// SPDX-License-Identifier: CAL
pragma solidity ^0.8.18;

import "rain.interpreter/src/interface/IInterpreterCallerV2.sol";
import "rain.interpreter/src/lib/caller/LibEvaluable.sol";
import {Sentinel} from "rain.solmem/lib/LibStackSentinel.sol";
import {MIN_FLOW_SENTINELS, SENTINEL_HIGH_BITS, FlowTransferV1} from "./IFlowV3.sol";

/// @dev v3 of `FlowERC20` expected a sentinel different to
/// `RAIN_FLOW_SENTINEL`, but this was generally more confusing than helpful.
Sentinel constant RAIN_FLOW_ERC20_SENTINEL =
    Sentinel.wrap(uint256(keccak256(bytes("RAIN_FLOW_ERC20_SENTINEL")) | SENTINEL_HIGH_BITS));

/// @dev Entrypont of the `handleTransfer` evaluation.
SourceIndex constant FLOW_ERC20_HANDLE_TRANSFER_ENTRYPOINT = SourceIndex.wrap(0);

/// @dev Minimum number of outputs of the `handleTransfer` evaluation.
/// This is 0 because the return stack is ignored.
uint256 constant FLOW_ERC20_HANDLE_TRANSFER_MIN_OUTPUTS = 0;

/// @dev Maximum number of outputs of the `handleTransfer` evaluation.
/// This is 0 because the return stack is ignored.
uint16 constant FLOW_ERC20_HANDLE_TRANSFER_MAX_OUTPUTS = 0;

/// @dev Minimum number of sentinels required by `FlowERC20`.
/// This is 2 more than the minimum required by `FlowCommon` because the
/// mints and burns are included in the stack.
uint256 constant FLOW_ERC20_MIN_FLOW_SENTINELS = MIN_FLOW_SENTINELS + 2;

/// Represents a single mint or burn of a single ERC20 token. Whether this is
/// a mint or burn must be implied by the context.
/// @param account The address the token is being minted/burned to/from.
/// @param amount The amount of the token being minted/burned.
struct ERC20SupplyChange {
    address account;
    uint256 amount;
}

/// Represents a set of ERC20 transfers, including self mints/burns.
/// @param mints The mints that occurred.
/// @param burns The burns that occurred.
/// @param flow The transfers that occured.
struct FlowERC20IOV1 {
    ERC20SupplyChange[] mints;
    ERC20SupplyChange[] burns;
    FlowTransferV1 flow;
}

/// Initializer config.
/// @param name As per Open Zeppelin `ERC20Upgradeable`.
/// @param symbol As per Open Zeppelin `ERC20Upgradeable`.
/// @param evaluableConfig The `EvaluableConfigV2` to use to build the
/// `evaluable` that can be used to handle transfers.
/// @param flowConfig Initializer config for the `Evaluable`s that define the
/// flow behaviours including self mints/burns.
struct FlowERC20Config {
    string name;
    string symbol;
    EvaluableConfig evaluableConfig;
    EvaluableConfig[] flowConfig;
}

/// @title IFlowERC20V3
/// @notice Mints itself according to some predefined schedule. The schedule is
/// expressed as an expression and the `claim` function is world-callable.
/// Intended behaviour is to avoid sybils infinitely minting by putting the
/// claim functionality behind a `TierV2` contract. The flow contract
/// itself implements `ReadOnlyTier` and every time a claim is processed it
/// logs the block number of the claim against every tier claimed. So the block
/// numbers in the tier report for `FlowERC20` are the last time that tier
/// was claimed against this contract. The simplest way to make use of this
/// information is to take the max block for the underlying tier and the last
/// claim and then diff it against the current block number.
/// See `test/Claim/FlowERC20.sol.ts` for examples, including providing
/// staggered rewards where more tokens are minted for higher tier accounts.
interface IFlowERC20V3 {
    /// Contract has initialized.
    /// @param sender `msg.sender` initializing the contract (factory).
    /// @param config All initialized config.
    event Initialize(address sender, FlowERC20Config config);

    /// As per `IFlowV3` but returns a `FlowERC20IOV1` instead of a
    /// `FlowTransferV1`.
    /// @param evaluable The `Evaluable` to use to evaluate the flow.
    /// @param callerContext The caller context to use to evaluate the flow.
    /// @param signedContexts The signed contexts to use to evaluate the flow.
    /// @return flowERC20IO The `FlowERC20IOV1` that occurred.
    function previewFlow(
        Evaluable calldata evaluable,
        uint256[] calldata callerContext,
        SignedContextV1[] calldata signedContexts
    ) external view returns (FlowERC20IOV1 calldata flowERC20IO);

    /// As per `IFlowV3` but returns a `FlowERC20IOV1` instead of a
    /// `FlowTransferV1` and mints/burns itself as an ERC20 accordingly.
    /// @param evaluable The `Evaluable` to use to evaluate the flow.
    /// @param callerContext The caller context to use to evaluate the flow.
    /// @param signedContexts The signed contexts to use to evaluate the flow.
    /// @return flowERC20IO The `FlowERC20IOV1` that occurred.
    function flow(
        Evaluable calldata evaluable,
        uint256[] calldata callerContext,
        SignedContextV1[] calldata signedContexts
    ) external returns (FlowERC20IOV1 calldata flowERC20IO);
}
