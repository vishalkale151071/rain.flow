// SPDX-License-Identifier: CAL
pragma solidity =0.8.19;

import {ERC1155Upgradeable as ERC1155} from
    "openzeppelin-contracts-upgradeable/contracts/token/ERC1155/ERC1155Upgradeable.sol";

import {LibEncodedDispatch, EncodedDispatch} from "rain.interpreter/src/lib/caller/LibEncodedDispatch.sol";
import {Sentinel, LibStackSentinel} from "rain.solmem/lib/LibStackSentinel.sol";
import {ICloneableV2, ICLONEABLE_V2_SUCCESS} from "rain.factory/src/interface/ICloneableV2.sol";
import {LibUint256Array} from "rain.solmem/lib/LibUint256Array.sol";
import {LibUint256Matrix} from "rain.solmem/lib/LibUint256Matrix.sol";
import {
    IFlowERC1155V4,
    FlowERC1155IOV1,
    SignedContextV1,
    FlowERC1155ConfigV2,
    ERC1155SupplyChange
} from "../../interface/unstable/IFlowERC1155V4.sol";
import {LibBytecode} from "lib/rain.interpreter/src/lib/bytecode/LibBytecode.sol";
import {IInterpreterV1} from "rain.interpreter/src/interface/IInterpreterV1.sol";
import {IInterpreterStoreV1} from "rain.interpreter/src/interface/IInterpreterStoreV1.sol";
import {Evaluable, DEFAULT_STATE_NAMESPACE} from "rain.interpreter/src/lib/caller/LibEvaluable.sol";
import {Pointer} from "rain.solmem/lib/LibPointer.sol";
import {SENTINEL_HIGH_BITS, LibFlow} from "../../lib/LibFlow.sol";
import {SourceIndex} from "rain.interpreter/src/interface/IInterpreterV1.sol";
import {
    MIN_FLOW_SENTINELS,
    FlowCommon,
    DeployerDiscoverableMetaV2ConstructionConfig,
    ERC1155Receiver
} from "../../abstract/FlowCommon.sol";
import {LibContext} from "rain.interpreter/src/lib/caller/LibContext.sol";

Sentinel constant RAIN_FLOW_ERC1155_SENTINEL =
    Sentinel.wrap(uint256(keccak256(bytes("RAIN_FLOW_ERC1155_SENTINEL")) | SENTINEL_HIGH_BITS));

bytes32 constant CALLER_META_HASH = bytes32(0x7ea70f837234357ec1bb5b777e04453ebaf3ca778a98805c4bb20a738d559a21);

SourceIndex constant HANDLE_TRANSFER_ENTRYPOINT = SourceIndex.wrap(0);
uint256 constant HANDLE_TRANSFER_MIN_OUTPUTS = 0;
uint16 constant HANDLE_TRANSFER_MAX_OUTPUTS = 0;

uint256 constant FLOW_ERC1155_MIN_OUTPUTS = MIN_FLOW_SENTINELS + 2;

contract FlowERC1155 is ICloneableV2, IFlowERC1155V4, FlowCommon, ERC1155 {
    using LibStackSentinel for Pointer;
    using LibUint256Matrix for uint256[];

    bool private sEvalHandleTransfer;
    Evaluable internal sEvaluable;

    constructor(DeployerDiscoverableMetaV2ConstructionConfig memory config) FlowCommon(CALLER_META_HASH, config) {}

    /// @inheritdoc ICloneableV2
    function initialize(bytes calldata data) external initializer returns (bytes32) {
        FlowERC1155ConfigV2 memory flowERC1155Config = abi.decode(data, (FlowERC1155ConfigV2));
        emit Initialize(msg.sender, flowERC1155Config);
        __ERC1155_init(flowERC1155Config.uri);

        // Set state before external calls here.
        bool evalHandleTransfer = LibBytecode.sourceCount(flowERC1155Config.evaluableConfig.bytecode) > 0
            && LibBytecode.sourceOpsLength(
                flowERC1155Config.evaluableConfig.bytecode, SourceIndex.unwrap(HANDLE_TRANSFER_ENTRYPOINT)
            ) > 0;
        sEvalHandleTransfer = evalHandleTransfer;

        flowCommonInit(flowERC1155Config.flowConfig, FLOW_ERC1155_MIN_OUTPUTS);

        if (evalHandleTransfer) {
            (IInterpreterV1 interpreter, IInterpreterStoreV1 store, address expression) = flowERC1155Config
                .evaluableConfig
                .deployer
                .deployExpression(
                flowERC1155Config.evaluableConfig.bytecode,
                flowERC1155Config.evaluableConfig.constants,
                LibUint256Array.arrayFrom(HANDLE_TRANSFER_MIN_OUTPUTS)
            );
            // There's no way to set this before the external call because the
            // output of the `deployExpression` call is the input to `Evaluable`.
            // Even if we could set it before the external call, we wouldn't want
            // to because the evaluable should not be registered before the
            // integrity checks are complete.
            // The deployer MUST be a trusted contract anyway.
            // slither-disable-next-line reentrancy-benign
            sEvaluable = Evaluable(interpreter, store, expression);
        }

        return ICLONEABLE_V2_SUCCESS;
    }

    function _dispatchHandleTransfer(address expression) internal pure returns (EncodedDispatch) {
        return LibEncodedDispatch.encode(expression, HANDLE_TRANSFER_ENTRYPOINT, HANDLE_TRANSFER_MAX_OUTPUTS);
    }

    /// Needed here to fix Open Zeppelin implementing `supportsInterface` on
    /// multiple base contracts.
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC1155, ERC1155Receiver)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    /// @inheritdoc ERC1155
    function _afterTokenTransfer(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal virtual override {
        unchecked {
            super._afterTokenTransfer(operator, from, to, ids, amounts, data);
            // Mint and burn access MUST be handled by flow.
            // HANDLE_TRANSFER will only restrict subsequent transfers.
            if (sEvalHandleTransfer && !(from == address(0) || to == address(0))) {
                Evaluable memory evaluable = sEvaluable;
                uint256[][] memory context;
                {
                    context = LibContext.build(
                        // The transfer params are caller context because the caller
                        // is triggering the transfer.
                        LibUint256Matrix.matrixFrom(
                            LibUint256Array.arrayFrom(
                                uint256(uint160(operator)), uint256(uint160(from)), uint256(uint160(to))
                            ),
                            ids,
                            amounts
                        ),
                        new SignedContextV1[](0)
                    );
                }

                (uint256[] memory stack, uint256[] memory kvs) = evaluable.interpreter.eval(
                    evaluable.store, DEFAULT_STATE_NAMESPACE, _dispatchHandleTransfer(evaluable.expression), context
                );
                (stack);
                if (kvs.length > 0) {
                    evaluable.store.set(DEFAULT_STATE_NAMESPACE, kvs);
                }
            }
        }
    }

    function _previewFlow(Evaluable memory evaluable, uint256[][] memory context)
        internal
        view
        returns (FlowERC1155IOV1 memory, uint256[] memory)
    {
        ERC1155SupplyChange[] memory mints;
        ERC1155SupplyChange[] memory burns;
        Pointer tuplesPointer;
        (Pointer stackBottom, Pointer stackTop, uint256[] memory kvs) = flowStack(evaluable, context);
        // mints
        // https://github.com/crytic/slither/issues/2126
        //slither-disable-next-line unused-return
        (stackTop, tuplesPointer) = stackBottom.consumeSentinelTuples(stackTop, RAIN_FLOW_ERC1155_SENTINEL, 3);
        assembly ("memory-safe") {
            mints := tuplesPointer
        }
        // burns
        // https://github.com/crytic/slither/issues/2126
        //slither-disable-next-line unused-return
        (stackTop, tuplesPointer) = stackBottom.consumeSentinelTuples(stackTop, RAIN_FLOW_ERC1155_SENTINEL, 3);
        assembly ("memory-safe") {
            burns := tuplesPointer
        }
        return (FlowERC1155IOV1(mints, burns, LibFlow.stackToFlow(stackBottom, stackTop)), kvs);
    }

    function _flow(Evaluable memory evaluable, uint256[] memory callerContext, SignedContextV1[] memory signedContexts)
        internal
        virtual
        nonReentrant
        returns (FlowERC1155IOV1 memory)
    {
        unchecked {
            uint256[][] memory context = LibContext.build(callerContext.matrixFrom(), signedContexts);
            emit Context(msg.sender, context);
            (FlowERC1155IOV1 memory flowIO, uint256[] memory kvs) = _previewFlow(evaluable, context);
            for (uint256 i = 0; i < flowIO.mints.length; i++) {
                // @todo support data somehow.
                _mint(flowIO.mints[i].account, flowIO.mints[i].id, flowIO.mints[i].amount, "");
            }
            for (uint256 i = 0; i < flowIO.burns.length; i++) {
                _burn(flowIO.burns[i].account, flowIO.burns[i].id, flowIO.burns[i].amount);
            }
            LibFlow.flow(flowIO.flow, evaluable.store, kvs);
            return flowIO;
        }
    }

    function previewFlow(
        Evaluable memory evaluable,
        uint256[] memory callerContext,
        SignedContextV1[] memory signedContexts
    ) external view virtual returns (FlowERC1155IOV1 memory) {
        uint256[][] memory context = LibContext.build(callerContext.matrixFrom(), signedContexts);
        (FlowERC1155IOV1 memory flowERC1155IO,) = _previewFlow(evaluable, context);
        return flowERC1155IO;
    }

    function flow(Evaluable memory evaluable, uint256[] memory callerContext, SignedContextV1[] memory signedContexts)
        external
        virtual
        returns (FlowERC1155IOV1 memory)
    {
        return _flow(evaluable, callerContext, signedContexts);
    }
}
