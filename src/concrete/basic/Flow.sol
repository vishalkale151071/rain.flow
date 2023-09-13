// SPDX-License-Identifier: CAL
pragma solidity =0.8.19;

import {ICloneableV2, ICLONEABLE_V2_SUCCESS} from "rain.factory/src/interface/ICloneableV2.sol";
import {
    FlowCommon,
    DeployerDiscoverableMetaV2ConstructionConfig,
    LibContext,
    MIN_FLOW_SENTINELS
} from "../../abstract/FlowCommon.sol";
import {IFlowV4, Evaluable, FlowTransferV1, SignedContextV1, EvaluableConfigV2, LibFlow} from "../../lib/LibFlow.sol";
import {LibUint256Matrix} from "rain.solmem/lib/LibUint256Matrix.sol";
import {Pointer} from "rain.solmem/lib/LibPointer.sol";

bytes32 constant CALLER_META_HASH = bytes32(0x95de68a447a477b8fab10701f1265b3e85a98b24710b3e40e6a96aa6d76263bc);

contract Flow is ICloneableV2, IFlowV4, FlowCommon {
    using LibUint256Matrix for uint256[];

    constructor(DeployerDiscoverableMetaV2ConstructionConfig memory config) FlowCommon(CALLER_META_HASH, config) {}

    /// @inheritdoc ICloneableV2
    function initialize(bytes calldata data) external initializer returns (bytes32) {
        EvaluableConfigV2[] memory flowConfig = abi.decode(data, (EvaluableConfigV2[]));
        emit Initialize(msg.sender, flowConfig);

        flowCommonInit(flowConfig, MIN_FLOW_SENTINELS);
        return ICLONEABLE_V2_SUCCESS;
    }

    function _previewFlow(Evaluable memory evaluable, uint256[][] memory context)
        internal
        view
        returns (FlowTransferV1 memory, uint256[] memory)
    {
        (Pointer stackBottom, Pointer stackTop, uint256[] memory kvs) = flowStack(evaluable, context);
        return (LibFlow.stackToFlow(stackBottom, stackTop), kvs);
    }

    function previewFlow(
        Evaluable memory evaluable,
        uint256[] memory callerContext,
        SignedContextV1[] memory signedContexts
    ) external view virtual returns (FlowTransferV1 memory) {
        uint256[][] memory context = LibContext.build(callerContext.matrixFrom(), signedContexts);
        (FlowTransferV1 memory flowTransfer,) = _previewFlow(evaluable, context);
        return flowTransfer;
    }

    function flow(Evaluable memory evaluable, uint256[] memory callerContext, SignedContextV1[] memory signedContexts)
        external
        virtual
        nonReentrant
        returns (FlowTransferV1 memory)
    {
        uint256[][] memory context = LibContext.build(callerContext.matrixFrom(), signedContexts);
        emit Context(msg.sender, context);
        (FlowTransferV1 memory flowTransfer, uint256[] memory kvs) = _previewFlow(evaluable, context);
        LibFlow.flow(flowTransfer, evaluable.store, kvs);
        return flowTransfer;
    }
}
