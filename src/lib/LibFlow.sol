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

library LibFlow {
    using SafeERC20 for IERC20;
    using LibStackSentinel for Pointer;
    using LibFlow for FlowTransferV1;

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

    function flowERC721(FlowTransferV1 memory flowTransfer) internal {
        unchecked {
            ERC721Transfer memory transfer;
            for (uint256 i = 0; i < flowTransfer.erc721.length; i++) {
                transfer = flowTransfer.erc721[i];
                if (transfer.from != msg.sender && transfer.from != address(this)) {
                    revert UnsupportedERC721Flow();
                }
                IERC721(transfer.token).safeTransferFrom(transfer.from, transfer.to, transfer.id);
            }
        }
    }

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
