// SPDX-License-Identifier: CAL
pragma solidity =0.8.19;

import {ReentrancyGuardUpgradeable as ReentrancyGuard} from
    "openzeppelin-contracts-upgradeable/contracts/security/ReentrancyGuardUpgradeable.sol";
import {ERC1155Upgradeable as ERC1155} from
    "openzeppelin-contracts-upgradeable/contracts/token/ERC1155/ERC1155Upgradeable.sol";
import {ERC1155ReceiverUpgradeable as ERC1155Receiver} from
    "openzeppelin-contracts-upgradeable/contracts/token/ERC1155/utils/ERC1155ReceiverUpgradeable.sol";

import "rain.interpreter/src/lib/caller/LibEncodedDispatch.sol";
import "rain.factory/src/interface/ICloneableV2.sol";
import "rain.solmem/lib/LibUint256Matrix.sol";
import "../../interface/unstable/IFlowERC1155V4.sol";
import "lib/rain.interpreter/src/lib/bytecode/LibBytecode.sol";

import "rain.solmem/lib/LibStackPointer.sol";
import "../../lib/LibFlow.sol";
import "../../abstract/FlowCommon.sol";

Sentinel constant RAIN_FLOW_ERC1155_SENTINEL =
    Sentinel.wrap(uint256(keccak256(bytes("RAIN_FLOW_ERC1155_SENTINEL")) | SENTINEL_HIGH_BITS));

bytes32 constant CALLER_META_HASH = bytes32(0x7ea70f837234357ec1bb5b777e04453ebaf3ca778a98805c4bb20a738d559a21);

SourceIndex constant HANDLE_TRANSFER_ENTRYPOINT = SourceIndex.wrap(0);
uint256 constant HANDLE_TRANSFER_MIN_OUTPUTS = 0;
uint16 constant HANDLE_TRANSFER_MAX_OUTPUTS = 0;

uint256 constant FLOW_ERC1155_MIN_OUTPUTS = MIN_FLOW_SENTINELS + 2;

contract FlowERC1155 is ICloneableV2, IFlowERC1155V4, ReentrancyGuard, FlowCommon, ERC1155 {
    using LibStackPointer for Pointer;
    using LibStackSentinel for Pointer;
    using LibStackPointer for uint256[];
    using LibUint256Array for uint256;
    using LibUint256Array for uint256[];
    using LibUint256Matrix for uint256[];

    bool private evalHandleTransfer;
    Evaluable internal sEvaluable;

    constructor(DeployerDiscoverableMetaV2ConstructionConfig memory config) FlowCommon(CALLER_META_HASH, config) {}

    /// @inheritdoc ICloneableV2
    function initialize(bytes calldata data) external initializer returns (bytes32) {
        FlowERC1155ConfigV2 memory flowERC1155Config = abi.decode(data, (FlowERC1155ConfigV2));
        emit Initialize(msg.sender, flowERC1155Config);
        __ReentrancyGuard_init();
        __ERC1155_init(flowERC1155Config.uri);

        flowCommonInit(flowERC1155Config.flowConfig, FLOW_ERC1155_MIN_OUTPUTS);

        if (
            LibBytecode.sourceCount(flowERC1155Config.evaluableConfig.bytecode) > 0
                && LibBytecode.sourceOpsLength(
                    flowERC1155Config.evaluableConfig.bytecode, SourceIndex.unwrap(HANDLE_TRANSFER_ENTRYPOINT)
                ) > 0
        ) {
            evalHandleTransfer = true;
            (IInterpreterV1 interpreter, IInterpreterStoreV1 store, address expression) = flowERC1155Config
                .evaluableConfig
                .deployer
                .deployExpression(
                flowERC1155Config.evaluableConfig.bytecode,
                flowERC1155Config.evaluableConfig.constants,
                LibUint256Array.arrayFrom(HANDLE_TRANSFER_MIN_OUTPUTS)
            );
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
            if (evalHandleTransfer && !(from == address(0) || to == address(0))) {
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
        (stackTop, tuplesPointer) = stackBottom.consumeSentinelTuples(stackTop, RAIN_FLOW_ERC1155_SENTINEL, 3);
        assembly ("memory-safe") {
            mints := tuplesPointer
        }
        // burns
        (stackTop, tuplesPointer) = stackBottom.consumeSentinelTuples(stackTop, RAIN_FLOW_ERC1155_SENTINEL, 3);
        assembly ("memory-safe") {
            burns := tuplesPointer
        }
        return (FlowERC1155IOV1(mints, burns, LibFlow.stackToFlow(stackBottom, stackTop)), kvs);
    }

    function _flow(
        Evaluable memory evaluable_,
        uint256[] memory callerContext_,
        SignedContextV1[] memory signedContexts_
    ) internal virtual nonReentrant returns (FlowERC1155IOV1 memory) {
        unchecked {
            uint256[][] memory context_ = LibContext.build(callerContext_.matrixFrom(), signedContexts_);
            emit Context(msg.sender, context_);
            (FlowERC1155IOV1 memory flowIO_, uint256[] memory kvs_) = _previewFlow(evaluable_, context_);
            for (uint256 i_ = 0; i_ < flowIO_.mints.length; i_++) {
                // @todo support data somehow.
                _mint(flowIO_.mints[i_].account, flowIO_.mints[i_].id, flowIO_.mints[i_].amount, "");
            }
            for (uint256 i_ = 0; i_ < flowIO_.burns.length; i_++) {
                _burn(flowIO_.burns[i_].account, flowIO_.burns[i_].id, flowIO_.burns[i_].amount);
            }
            LibFlow.flow(flowIO_.flow, evaluable_.store, kvs_);
            return flowIO_;
        }
    }

    function previewFlow(
        Evaluable memory evaluable_,
        uint256[] memory callerContext_,
        SignedContextV1[] memory signedContexts_
    ) external view virtual returns (FlowERC1155IOV1 memory) {
        uint256[][] memory context_ = LibContext.build(callerContext_.matrixFrom(), signedContexts_);
        (FlowERC1155IOV1 memory flowERC1155IO_,) = _previewFlow(evaluable_, context_);
        return flowERC1155IO_;
    }

    function flow(
        Evaluable memory evaluable_,
        uint256[] memory callerContext_,
        SignedContextV1[] memory signedContexts_
    ) external virtual returns (FlowERC1155IOV1 memory) {
        return _flow(evaluable_, callerContext_, signedContexts_);
    }
}
