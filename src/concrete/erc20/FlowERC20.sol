// SPDX-License-Identifier: CAL
pragma solidity =0.8.19;

import {ERC20Upgradeable as ERC20} from "openzeppelin-contracts-upgradeable/contracts/token/ERC20/ERC20Upgradeable.sol";

import {LibUint256Array} from "rain.solmem/lib/LibUint256Array.sol";
import {LibUint256Matrix} from "rain.solmem/lib/LibUint256Matrix.sol";
import {ICloneableV2, ICLONEABLE_V2_SUCCESS} from "rain.factory/src/interface/ICloneableV2.sol";
import {
    IFlowERC20V4,
    FlowERC20IOV1,
    FlowERC20ConfigV2,
    ERC20SupplyChange,
    SignedContextV1
} from "../../interface/unstable/IFlowERC20V4.sol";
import {LibBytecode} from "lib/rain.interpreter/src/lib/bytecode/LibBytecode.sol";
import {EncodedDispatch, LibEncodedDispatch} from "rain.interpreter/src/lib/caller/LibEncodedDispatch.sol";

import {Sentinel, LibStackSentinel} from "rain.solmem/lib/LibStackSentinel.sol";
import {SENTINEL_HIGH_BITS, LibFlow} from "../../lib/LibFlow.sol";
import {
    FlowCommon,
    DeployerDiscoverableMetaV2,
    DeployerDiscoverableMetaV2ConstructionConfig,
    MIN_FLOW_SENTINELS
} from "../../abstract/FlowCommon.sol";
import {SourceIndex, IInterpreterV1} from "rain.interpreter/src/interface/IInterpreterV1.sol";
import {IInterpreterStoreV1} from "rain.interpreter/src/interface/IInterpreterStoreV1.sol";
import {Pointer} from "rain.solmem/lib/LibPointer.sol";
import {Evaluable, DEFAULT_STATE_NAMESPACE} from "rain.interpreter/src/lib/caller/LibEvaluable.sol";
import {LibContext} from "rain.interpreter/src/lib/caller/LibContext.sol";

bytes32 constant CALLER_META_HASH = bytes32(0xff0499e4ee7171a54d176cfe13165a7ea512d146dbd99d42b3d3ec9963025acf);

Sentinel constant RAIN_FLOW_ERC20_SENTINEL =
    Sentinel.wrap(uint256(keccak256(bytes("RAIN_FLOW_ERC20_SENTINEL")) | SENTINEL_HIGH_BITS));

SourceIndex constant HANDLE_TRANSFER_ENTRYPOINT = SourceIndex.wrap(0);
uint256 constant HANDLE_TRANSFER_MIN_OUTPUTS = 0;
uint16 constant HANDLE_TRANSFER_MAX_OUTPUTS = 0;

/// @title FlowERC20
contract FlowERC20 is ICloneableV2, IFlowERC20V4, FlowCommon, ERC20 {
    using LibStackSentinel for Pointer;
    using LibUint256Matrix for uint256[];

    bool private sEvalHandleTransfer;
    Evaluable internal sEvaluable;

    constructor(DeployerDiscoverableMetaV2ConstructionConfig memory config) FlowCommon(CALLER_META_HASH, config) {}

    /// @inheritdoc ICloneableV2
    function initialize(bytes calldata data) external initializer returns (bytes32) {
        FlowERC20ConfigV2 memory flowERC20Config = abi.decode(data, (FlowERC20ConfigV2));
        emit Initialize(msg.sender, flowERC20Config);
        __ERC20_init(flowERC20Config.name, flowERC20Config.symbol);

        flowCommonInit(flowERC20Config.flowConfig, MIN_FLOW_SENTINELS + 2);

        if (
            LibBytecode.sourceCount(flowERC20Config.evaluableConfig.bytecode) > 0
                && LibBytecode.sourceOpsLength(
                    flowERC20Config.evaluableConfig.bytecode, SourceIndex.unwrap(HANDLE_TRANSFER_ENTRYPOINT)
                ) > 0
        ) {
            sEvalHandleTransfer = true;
            (IInterpreterV1 interpreter, IInterpreterStoreV1 store, address expression) = flowERC20Config
                .evaluableConfig
                .deployer
                .deployExpression(
                flowERC20Config.evaluableConfig.bytecode,
                flowERC20Config.evaluableConfig.constants,
                LibUint256Array.arrayFrom(HANDLE_TRANSFER_MIN_OUTPUTS)
            );
            sEvaluable = Evaluable(interpreter, store, expression);
        }

        return ICLONEABLE_V2_SUCCESS;
    }

    function _dispatchHandleTransfer(address expression) internal pure returns (EncodedDispatch) {
        return LibEncodedDispatch.encode(expression, HANDLE_TRANSFER_ENTRYPOINT, HANDLE_TRANSFER_MAX_OUTPUTS);
    }

    /// @inheritdoc ERC20
    function _afterTokenTransfer(address from, address to, uint256 amount) internal virtual override {
        unchecked {
            super._afterTokenTransfer(from, to, amount);

            // Mint and burn access MUST be handled by flow.
            // HANDLE_TRANSFER will only restrict subsequent transfers.
            if (sEvalHandleTransfer && !(from == address(0) || to == address(0))) {
                Evaluable memory evaluable = sEvaluable;
                (, uint256[] memory kvs) = evaluable.interpreter.eval(
                    evaluable.store,
                    DEFAULT_STATE_NAMESPACE,
                    _dispatchHandleTransfer(evaluable.expression),
                    LibContext.build(
                        // The transfer params are caller context because the caller
                        // is triggering the transfer.
                        LibUint256Array.arrayFrom(uint256(uint160(from)), uint256(uint160(to)), amount).matrixFrom(),
                        new SignedContextV1[](0)
                    )
                );
                if (kvs.length > 0) {
                    evaluable.store.set(DEFAULT_STATE_NAMESPACE, kvs);
                }
            }
        }
    }

    function _previewFlow(Evaluable memory evaluable, uint256[][] memory context)
        internal
        view
        virtual
        returns (FlowERC20IOV1 memory, uint256[] memory)
    {
        ERC20SupplyChange[] memory mints;
        ERC20SupplyChange[] memory burns;
        Pointer tuplesPointer;
        (Pointer stackBottom, Pointer stackTop, uint256[] memory kvs) = flowStack(evaluable, context);
        // mints
        (stackTop, tuplesPointer) = stackBottom.consumeSentinelTuples(stackTop, RAIN_FLOW_ERC20_SENTINEL, 2);
        assembly ("memory-safe") {
            mints := tuplesPointer
        }
        // burns
        (stackTop, tuplesPointer) = stackBottom.consumeSentinelTuples(stackTop, RAIN_FLOW_ERC20_SENTINEL, 2);
        assembly ("memory-safe") {
            burns := tuplesPointer
        }

        return (FlowERC20IOV1(mints, burns, LibFlow.stackToFlow(stackBottom, stackTop)), kvs);
    }

    function _flow(Evaluable memory evaluable, uint256[] memory callerContext, SignedContextV1[] memory signedContexts)
        internal
        virtual
        nonReentrant
        returns (FlowERC20IOV1 memory)
    {
        unchecked {
            uint256[][] memory context = LibContext.build(callerContext.matrixFrom(), signedContexts);
            emit Context(msg.sender, context);
            (FlowERC20IOV1 memory flowIO, uint256[] memory kvs) = _previewFlow(evaluable, context);
            for (uint256 i = 0; i < flowIO.mints.length; i++) {
                _mint(flowIO.mints[i].account, flowIO.mints[i].amount);
            }
            for (uint256 i = 0; i < flowIO.burns.length; i++) {
                _burn(flowIO.burns[i].account, flowIO.burns[i].amount);
            }
            LibFlow.flow(flowIO.flow, evaluable.store, kvs);
            return flowIO;
        }
    }

    function previewFlow(
        Evaluable memory evaluable,
        uint256[] memory callerContext,
        SignedContextV1[] memory signedContexts
    ) external view virtual returns (FlowERC20IOV1 memory) {
        uint256[][] memory context = LibContext.build(callerContext.matrixFrom(), signedContexts);
        (FlowERC20IOV1 memory flowERC20IO,) = _previewFlow(evaluable, context);
        return flowERC20IO;
    }

    function flow(Evaluable memory evaluable, uint256[] memory callerContext, SignedContextV1[] memory signedContexts)
        external
        virtual
        returns (FlowERC20IOV1 memory)
    {
        return _flow(evaluable, callerContext, signedContexts);
    }
}
