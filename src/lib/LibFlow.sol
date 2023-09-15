// SPDX-License-Identifier: CAL
pragma solidity ^0.8.18;

import {IFlowV4, RAIN_FLOW_SENTINEL} from "../interface/unstable/IFlowV4.sol";
import {Pointer} from "rain.solmem/lib/LibPointer.sol";
import {
    FlowTransferV1,
    ERC20Transfer,
    ERC721Transfer,
    ERC1155Transfer,
    UnsupportedERC20Flow,
    UnsupportedERC721Flow,
    UnsupportedERC1155Flow
} from "../interface/unstable/IFlowV4.sol";
import {IInterpreterStoreV1, DEFAULT_STATE_NAMESPACE} from "rain.interpreter/src/interface/IInterpreterStoreV1.sol";
import {LibStackSentinel} from "rain.solmem/lib/LibStackSentinel.sol";

import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC721} from "openzeppelin-contracts/contracts/token/ERC721/IERC721.sol";
import {IERC1155} from "openzeppelin-contracts/contracts/token/ERC1155/IERC1155.sol";

/// @title LibFlow
/// Standard processing used by all variants of `Flow`. These utilities can't
/// be directly embedded in `FlowCommon` because each variant of `Flow` has
/// slightly different requirements to incorporate mints and burns as well as
/// the basic transfer handling.
library LibFlow {
    using SafeERC20 for IERC20;
    using LibStackSentinel for Pointer;
    using LibFlow for FlowTransferV1;

    /// Converts pointers bounding an evaluated stack to a `FlowTransferV1`.
    /// Works by repeatedly consuming sentinel tuples from the stack, where the
    /// tuple size is 4 for ERC20, 4 for ERC721 and 5 for ERC1155. The sentinels
    /// are consumed from the stack from top to bottom, so the first sentinels
    /// consumed are the ERC20 transfers, followed by the ERC721 transfers and
    /// finally the ERC1155 transfers.
    /// @param stackBottom The bottom of the stack.
    /// @param stackTop The top of the stack.
    /// @return The `FlowTransferV1` representing the transfers in the stack.
    function stackToFlow(Pointer stackBottom, Pointer stackTop) internal pure returns (FlowTransferV1 memory) {
        unchecked {
            ERC20Transfer[] memory erc20;
            ERC721Transfer[] memory erc721;
            ERC1155Transfer[] memory erc1155;
            Pointer tuplesPointer;
            // erc20
            (stackTop, tuplesPointer) = stackBottom.consumeSentinelTuples(stackTop, RAIN_FLOW_SENTINEL, 4);
            assembly ("memory-safe") {
                erc20 := tuplesPointer
            }
            // erc721
            (stackTop, tuplesPointer) = stackBottom.consumeSentinelTuples(stackTop, RAIN_FLOW_SENTINEL, 4);
            assembly ("memory-safe") {
                erc721 := tuplesPointer
            }
            // erc1155
            (stackTop, tuplesPointer) = stackBottom.consumeSentinelTuples(stackTop, RAIN_FLOW_SENTINEL, 5);
            assembly ("memory-safe") {
                erc1155 := tuplesPointer
            }
            return FlowTransferV1(erc20, erc721, erc1155);
        }
    }

    /// Processes the ERC20 transfers in the flow.
    /// Reverts if the `from` address is not either the `msg.sender` or the
    /// flow contract. Uses `IERC20.safeTransferFrom` to transfer the tokens to
    /// ensure that reverts from the token are respected.
    /// @param flowTransfer The `FlowTransferV1` to process. Tokens other than
    /// ERC20 tokens are ignored.
    function flowERC20(FlowTransferV1 memory flowTransfer) internal {
        unchecked {
            ERC20Transfer memory transfer;
            for (uint256 i = 0; i < flowTransfer.erc20.length; i++) {
                transfer = flowTransfer.erc20[i];
                if (transfer.from == msg.sender) {
                    IERC20(transfer.token).safeTransferFrom(msg.sender, transfer.to, transfer.amount);
                } else if (transfer.from == address(this)) {
                    IERC20(transfer.token).safeTransfer(transfer.to, transfer.amount);
                } else {
                    // We don't support `from` as anyone other than `you` or `me`
                    // as this would allow for all kinds of issues re: approvals.
                    revert UnsupportedERC20Flow();
                }
            }
        }
    }

    /// Processes the ERC721 transfers in the flow.
    /// Reverts if the `from` address is not either the `msg.sender` or the
    /// flow contract. Uses `IERC721.safeTransferFrom` to transfer the tokens to
    /// ensure that reverts from the token are respected.
    /// @param flowTransfer The `FlowTransferV1` to process. Tokens other than
    /// ERC721 tokens are ignored.
    function flowERC721(FlowTransferV1 memory flowTransfer) internal {
        unchecked {
            ERC721Transfer memory transfer;
            for (uint256 i = 0; i < flowTransfer.erc721.length; ++i) {
                transfer = flowTransfer.erc721[i];
                if (transfer.from != msg.sender && transfer.from != address(this)) {
                    revert UnsupportedERC721Flow();
                }
                IERC721(transfer.token).safeTransferFrom(transfer.from, transfer.to, transfer.id);
            }
        }
    }

    /// Processes the ERC1155 transfers in the flow.
    /// Reverts if the `from` address is not either the `msg.sender` or the
    /// flow contract. Uses `IERC1155.safeTransferFrom` to transfer the tokens to
    /// ensure that reverts from the token are respected.
    /// @param flowTransfer The `FlowTransferV1` to process. Tokens other than
    /// ERC1155 tokens are ignored.
    function flowERC1155(FlowTransferV1 memory flowTransfer) internal {
        unchecked {
            ERC1155Transfer memory transfer;
            for (uint256 i = 0; i < flowTransfer.erc1155.length; i++) {
                transfer = flowTransfer.erc1155[i];
                if (transfer.from != msg.sender && transfer.from != address(this)) {
                    revert UnsupportedERC1155Flow();
                }
                // @todo safeBatchTransferFrom support.
                // @todo data support.
                IERC1155(transfer.token).safeTransferFrom(transfer.from, transfer.to, transfer.id, transfer.amount, "");
            }
        }
    }

    /// Processes a flow transfer. Firstly sets state for the interpreter on the
    /// interpreter store. Then processes the ERC20, ERC721 and ERC1155 transfers
    /// in the flow. Guarantees ordering of the transfers but DOES NOT prevent
    /// reentrancy attacks. This is the responsibility of the caller.
    /// @param flowTransfer The `FlowTransferV1` to process.
    /// @param interpreterStore The `IInterpreterStoreV1` to set state on.
    /// @param kvs The key value pairs to set on the interpreter store.
    function flow(FlowTransferV1 memory flowTransfer, IInterpreterStoreV1 interpreterStore, uint256[] memory kvs)
        internal
    {
        if (kvs.length > 0) {
            interpreterStore.set(DEFAULT_STATE_NAMESPACE, kvs);
        }
        flowTransfer.flowERC20();
        flowTransfer.flowERC721();
        flowTransfer.flowERC1155();
    }
}
