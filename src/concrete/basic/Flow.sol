// SPDX-License-Identifier: CAL
pragma solidity =0.8.19;

import "rain.factory/src/interface/ICloneableV2.sol";
import "../../abstract/FlowCommon.sol";
import "../../lib/LibFlow.sol";
import "rain.solmem/lib/LibUint256Array.sol";
import "rain.solmem/lib/LibUint256Matrix.sol";
import {ReentrancyGuard} from "openzeppelin-contracts/contracts/security/ReentrancyGuard.sol";

bytes32 constant CALLER_META_HASH = bytes32(0x95de68a447a477b8fab10701f1265b3e85a98b24710b3e40e6a96aa6d76263bc);

contract Flow is ICloneableV2, IFlowV4, ReentrancyGuard, FlowCommon {
    using LibUint256Array for uint256[];
    using LibUint256Matrix for uint256[];

    constructor(DeployerDiscoverableMetaV2ConstructionConfig memory config) FlowCommon(CALLER_META_HASH, config) {}

    /// @inheritdoc ICloneableV2
    function initialize(bytes calldata data) external initializer returns (bytes32) {
        EvaluableConfigV2[] memory flowConfig = abi.decode(data, (EvaluableConfigV2[]));
        emit Initialize(msg.sender, flowConfig);

        flowCommonInit(flowConfig, MIN_FLOW_SENTINELS);
        return ICLONEABLE_V2_SUCCESS;
    }

    function _previewFlow(Evaluable memory evaluable_, uint256[][] memory context_)
        internal
        view
        returns (FlowTransferV1 memory, uint256[] memory)
    {
        (Pointer stackBottom_, Pointer stackTop_, uint256[] memory kvs_) = flowStack(evaluable_, context_);
        return (LibFlow.stackToFlow(stackBottom_, stackTop_), kvs_);
    }

    function previewFlow(
        Evaluable memory evaluable_,
        uint256[] memory callerContext_,
        SignedContextV1[] memory signedContexts_
    ) external view virtual returns (FlowTransferV1 memory) {
        uint256[][] memory context_ = LibContext.build(callerContext_.matrixFrom(), signedContexts_);
        (FlowTransferV1 memory flowTransfer_,) = _previewFlow(evaluable_, context_);
        return flowTransfer_;
    }

    function flow(
        Evaluable memory evaluable_,
        uint256[] memory callerContext_,
        SignedContextV1[] memory signedContexts_
    ) external virtual nonReentrant returns (FlowTransferV1 memory) {
        uint256[][] memory context_ = LibContext.build(callerContext_.matrixFrom(), signedContexts_);
        emit Context(msg.sender, context_);
        (FlowTransferV1 memory flowTransfer_, uint256[] memory kvs_) = _previewFlow(evaluable_, context_);
        LibFlow.flow(flowTransfer_, evaluable_.store, kvs_);
        return flowTransfer_;
    }
}
