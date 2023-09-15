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

struct FlowConfig {
    // https://github.com/ethereum/solidity/issues/13597
    EvaluableConfig dummyConfig;
    EvaluableConfig[] config;
}

struct ERC20Transfer {
    address token;
    address from;
    address to;
    uint256 amount;
}

struct ERC721Transfer {
    address token;
    address from;
    address to;
    uint256 id;
}

struct ERC1155Transfer {
    address token;
    address from;
    address to;
    uint256 id;
    uint256 amount;
}

struct FlowTransferV1 {
    ERC20Transfer[] erc20;
    ERC721Transfer[] erc721;
    ERC1155Transfer[] erc1155;
}

interface IFlowV3 {
    event Initialize(address sender, FlowConfig config);

    function previewFlow(
        Evaluable calldata evaluable,
        uint256[] calldata callerContext,
        SignedContextV1[] calldata signedContexts
    ) external view returns (FlowTransferV1 calldata flowTransfer);

    function flow(
        Evaluable calldata evaluable,
        uint256[] calldata callerContext,
        SignedContextV1[] calldata signedContexts
    ) external returns (FlowTransferV1 calldata flowTransfer);
}
