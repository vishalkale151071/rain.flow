// SPDX-License-Identifier: CAL
pragma solidity ^0.8.18;

import {SignedContextV1} from "rain.interpreter/src/interface/IInterpreterCallerV2.sol";
import {EvaluableConfigV2, Evaluable} from "rain.interpreter/src/lib/caller/LibEvaluable.sol";
import {Sentinel} from "rain.solmem/lib/LibStackSentinel.sol";
import {Pointer} from "rain.solmem/lib/LibPointer.sol";

import {
    FlowTransferV1,
    ERC20Transfer,
    ERC721Transfer,
    ERC1155Transfer,
    RAIN_FLOW_SENTINEL,
    UnregisteredFlow,
    UnsupportedERC20Flow,
    UnsupportedERC721Flow,
    UnsupportedERC1155Flow,
    MIN_FLOW_SENTINELS
} from "../IFlowV3.sol";

/// @title IFlowV4
/// @notice Interface for a flow contract that does NOT require native minting
/// or burning of itself as a token. This is the base case that all other flow
/// interfaces model themselves after, with the addition of token minting and
/// burning.
///
/// Current functionality only allows for moving third party tokens between
/// accounts. Token standards ERC20, ERC721, and ERC1155 are supported.
///
/// The basic lifecycle of a flow is:
/// - `Flow` is deployed as a reference implementation to be cloned, with its
///   initializers disabled on construction.
/// - `Flow` is cloned and initialized with an abi encoded list of evaluable
///   configs that define every possible movement of tokens that can occur due
///   to the clone. The EOA that deployed the clone DOES NOT have any special
///   privileges over the clone, although they could grant themselves privileges
///   by flowing tokens to themselves or similar within the evaluables. Ideally
///   the EOA doesn't introduce "admin" features as it would be a security risk
///   to themselves and others. In the case that they do, all priviledges will
///   be visible in the rainlang code of the evaluable, there's no hidden
///   functionality that can be introduced to the clone bytecode.
/// - Anyone can call `flow` on the clone, passing in one of the evaluables set
///   during initialization. If the evaluable passed by the caller does not
///   match an initialized evaluable, the flow MUST revert with
///   `UnregisteredFlow`. The entirety of the resulting stack from the evaluation
///   defines all the token movements that MUST occur as a result of the flow.
///   ANY failures during the flow MUST revert the entire flow, leaving the
///   state of the tokens unchanged.
///
/// The structure of the stack can be thought of as a simple list of transfers.
/// All the erc20 tokens are moved first, then the erc721 tokens, then the
/// erc1155 tokens. Each token type is separated in the stack by a sentinel
/// value. The sentinel is a constant, `RAIN_FLOW_SENTINEL`, that is guaranteed
/// to not collide with any token amounts or addresses. The sentinel is also
/// guaranteed to not collide with any other sentinels from other contexts, to
/// the extent that we can guarantee that with raw cryptographic collision
/// resistance. This sentinel can be thought of as similar to the null terminator
/// in a c string, it's a value that is guaranteed to not be a valid value for
/// the type of data it's separating. The main benefit in this context, for
/// rainlang authors, is that they can always use the same constant value in
/// all their rainlang code to separate the different token types, rather than
/// needing to manually calculate the length of the tuples they're wanting to
/// flow over in each token type (which would be very error prone).
///
/// Currently every token transfer type MUST be present in every flow stack,
/// which is awkward as it means that if you want to flow erc20 tokens, you
/// MUST also flow erc721 and erc1155 tokens, even if you don't want to. This
/// is a limitation of the current implementation, and will be fixed in a future
/// version.
///
/// Each individual token transfer is simply a list of values, where the values
/// are specific to the token type.
/// - erc20 transfers are a list of 4 values:
///   - address of the token contract
///   - address of the token sender
///   - address of the token recipient
///   - amount of tokens to transfer
/// - erc721 transfers are a list of 4 values:
///   - address of the token contract
///   - address of the token sender
///   - address of the token recipient
///   - token id to transfer
/// - erc1155 transfers are a list of 5 values:
///   - address of the token contract
///   - address of the token sender
///   - address of the token recipient
///   - token id to transfer
///   - amount of tokens to transfer
///
/// The final stack is processed from the bottom up, so the first token transfer
/// in the stack is the last one to be processed.
///
/// For example, a rainlang expression that transfers 1e18 erc20 token 0xf00baa
/// from the flow contract to the address 0xdeadbeef, and 1 erc721 token address
/// 0x1234 and id 5678 from the address 0xdeadbeef to the flow contract, would
/// result in the following rainlang/stack:
///
/// ```
/// /* sentinel is always the same. */
/// sentinel: 0xfea74d0c9bf4a3c28f0dd0674db22a3d7f8bf259c56af19f4ac1e735b156974f,
/// /* erc1155 transfers are first, just a sentinel as there's nothing to do */
/// _: sentinel,
/// /* erc721 transfers are next, with the token id as the last value */
/// _: 0x1234 0xdeadbeef context<0 1>() 5678,
/// /* erc20 transfers are last, with the amount as the last value */
/// _: 0xf00baa context<0 1>() 0xdeadbeef 1e18;
/// ```
///
/// Note that for all token transfers the sender of the tokens MUST be either
/// the flow contract itself, or the caller of the flow contract. This is to
/// prevent the flow contract from being able to transfer tokens from arbitrary
/// addresses without their consent. Even if some address has approved the flow
/// contract to transfer tokens on their behalf, the flow contract MUST NOT
/// transfer tokens from that address unless the caller of the flow contract
/// is that address.
///
/// Note that native gas movements are not supported in this version of the
/// flow contract. This is because the current reference implementation uses
/// `Multicall` to batch together multiple calls to the flow contract, and
/// this involves a loop over a delegate call, which is not safe to do with
/// native gas movements. This will be fixed in a future version of the interface
/// where batching is handled by the flow contract itself, rather than relying
/// on `Multicall`.
interface IFlowV4 {
    /// MUST be emitted when the flow contract is initialized.
    /// @param sender The EOA that deployed the flow contract.
    /// @param config The list of evaluable configs that define the flows.
    event Initialize(address sender, EvaluableConfigV2[] config);

    /// Given a stack of values, convert it to a flow transfer. MUST NOT modify
    /// state but MAY revert if the stack is malformed. The intended workflow is
    /// that the interpreter contract is called to produce a stack then the stack
    /// is converted to a flow transfer struct, to allow the caller to preview
    /// a flow before actually executing it. By accepting a stack as input, the
    /// caller can preview any possible flow, not just ones that have been
    /// registered with the flow contract, and can preview flows that may not
    /// even be possible to execute due to the state of the tokens, or access
    /// gating that would exclude the caller, etc.
    /// @param stack The stack of values to convert to a flow transfer.
    /// @return flowTransfer The resulting flow transfer.
    function stackToFlow(uint256[] memory stack) external pure returns (FlowTransferV1 calldata flowTransfer);

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
