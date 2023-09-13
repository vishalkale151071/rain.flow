// SPDX-License-Identifier: CAL
pragma solidity ^0.8.18;

import "rain.interpreter/src/interface/IInterpreterCallerV2.sol";
import "rain.interpreter/src/lib/caller/LibEvaluable.sol";

import {FlowTransferV1, ERC20Transfer, ERC721Transfer, ERC1155Transfer} from "../IFlowV3.sol";

/// Thrown when the flow being evaluated is unregistered.
/// @param unregisteredHash Hash of the unregistered flow.
error UnregisteredFlow(bytes32 unregisteredHash);

/// @title IFlowV4
/// @notice Interface for a flow contract that does NOT require native minting
/// or burning of itself as a token. This is the base case that all other flow
/// interfaces model themselves after, with the addition of token minting and
/// burning.
interface IFlowV4 {
    event Initialize(address sender, EvaluableConfigV2[] config);

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
