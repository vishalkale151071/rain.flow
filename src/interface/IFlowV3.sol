// SPDX-License-Identifier: CAL
pragma solidity ^0.8.18;

import "rain.interpreter/src/interface/IInterpreterCallerV2.sol";
import "rain.interpreter/src/lib/caller/LibEvaluable.sol";
import {Sentinel} from "rain.solmem/lib/LibStackSentinel.sol";

/// Thrown when the flow being evaluated is unregistered.
/// @param unregisteredHash Hash of the unregistered flow.
error UnregisteredFlow(bytes32 unregisteredHash);

/// Thrown for unsupported native transfers.
error UnsupportedNativeFlow();

/// Thrown for unsupported erc20 transfers.
error UnsupportedERC20Flow();

/// Thrown for unsupported erc721 transfers.
error UnsupportedERC721Flow();

/// Thrown for unsupported erc1155 transfers.
error UnsupportedERC1155Flow();

/// @dev The number of sentinels required by `FlowCommon`. An evaluable can never
/// have fewer minimum outputs than required sentinels.
uint256 constant MIN_FLOW_SENTINELS = 3;

/// @dev Sets the high bits of all flow sentinels to guarantee that the numeric
/// value of the sentinel will never collide with a token amount or address. This
/// guarantee holds as long as the token supply is less than 2^252, and the
/// that token IDs have no specific reason to collide with the sentinel.
/// i.e. There won't be random collisions because the space of token IDs is
/// too large.
bytes32 constant SENTINEL_HIGH_BITS = bytes32(0xF000000000000000000000000000000000000000000000000000000000000000);

/// @dev We want a sentinel with the following properties:
/// - Won't collide with token amounts (| with very large number)
/// - Won't collide with token addresses
/// - Won't collide with common values like `type(uint256).max` and
///   `type(uint256).min`
/// - Won't collide with other sentinels from unrelated contexts
Sentinel constant RAIN_FLOW_SENTINEL =
    Sentinel.wrap(uint256(keccak256(bytes("RAIN_FLOW_SENTINEL")) | SENTINEL_HIGH_BITS));

/// Wraps `EvaluableConfig[]` to workaround a Solidity bug.
/// https://github.com/ethereum/solidity/issues/13597
/// @param dummyConfig A dummy config to workaround a Solidity bug.
/// @param config The list of evaluable configs that define the flows.
struct FlowConfig {
    EvaluableConfig dummyConfig;
    EvaluableConfig[] config;
}

/// Represents a single transfer of a single ERC20 token.
/// @param token The address of the ERC20 token being transferred.
/// @param from The address the token is being transferred from.
/// @param to The address the token is being transferred to.
/// @param amount The amount of the token being transferred.
struct ERC20Transfer {
    address token;
    address from;
    address to;
    uint256 amount;
}

/// Represents a single transfer of a single ERC721 token.
/// @param token The address of the ERC721 token being transferred.
/// @param from The address the token is being transferred from.
/// @param to The address the token is being transferred to.
/// @param id The id of the token being transferred.
struct ERC721Transfer {
    address token;
    address from;
    address to;
    uint256 id;
}

/// Represents a single transfer of a single ERC1155 token.
/// @param token The address of the ERC1155 token being transferred.
/// @param from The address the token is being transferred from.
/// @param to The address the token is being transferred to.
/// @param id The id of the token being transferred.
/// @param amount The amount of the token being transferred.
struct ERC1155Transfer {
    address token;
    address from;
    address to;
    uint256 id;
    uint256 amount;
}

/// Represents an ordered set of transfers that will be or have been executed.
/// Supports ERC20, ERC721, and ERC1155 transfers.
/// @param erc20 An array of ERC20 transfers.
/// @param erc721 An array of ERC721 transfers.
/// @param erc1155 An array of ERC1155 transfers.
struct FlowTransferV1 {
    ERC20Transfer[] erc20;
    ERC721Transfer[] erc721;
    ERC1155Transfer[] erc1155;
}

/// @title IFlowV3
/// At a high level, identical to `IFlowV4` but with an older, less flexible
/// previewing system, and the older `FlowConfig` struct that was used with
/// older versions of the interpreter.
interface IFlowV3 {
    /// MUST be emitted when the flow contract is initialized.
    /// @param sender The EOA that deployed the flow contract.
    /// @param config The list of evaluable configs that define the flows.
    event Initialize(address sender, FlowConfig config);

    /// "Dry run" of a flow, returning the resulting token transfers without
    /// actually executing them.
    /// @param evaluable The evaluable to evaluate.
    /// @param callerContext The caller context to use when evaluating the
    /// flow.
    /// @param signedContexts The signed contexts to use when evaluating the
    /// flow.
    function previewFlow(
        Evaluable calldata evaluable,
        uint256[] calldata callerContext,
        SignedContextV1[] calldata signedContexts
    ) external view returns (FlowTransferV1 calldata flowTransfer);

    /// Given an evaluable, caller context, and signed contexts, evaluate the
    /// evaluable and return the resulting flow transfer. MUST process the
    /// flow transfer atomically, either all of it succeeds or none of it
    /// succeeds. MUST revert if the evaluable is not registered with the flow
    /// contract. MUST revert if the evaluable reverts. MUST revert if the
    /// evaluable returns a stack that is malformed. MUST revert if the evaluable
    /// returns a stack that contains a token transfer that is not allowed by
    /// the flow contract (e.g. if a token is being moved from an address that
    /// is not the caller or the flow contract).
    /// @param evaluable The evaluable to evaluate.
    /// @param callerContext The caller context to pass to the evaluable.
    /// @param signedContexts The signed contexts to pass to the evaluable.
    /// @return flowTransfer The resulting flow transfer.
    function flow(
        Evaluable calldata evaluable,
        uint256[] calldata callerContext,
        SignedContextV1[] calldata signedContexts
    ) external returns (FlowTransferV1 calldata flowTransfer);
}
