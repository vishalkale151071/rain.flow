// SPDX-License-Identifier: CAL
pragma solidity =0.8.19;

import {ERC721Upgradeable as ERC721} from
    "openzeppelin-contracts-upgradeable/contracts/token/ERC721/ERC721Upgradeable.sol";

import {LibUint256Array} from "rain.solmem/lib/LibUint256Array.sol";
import {LibUint256Matrix} from "rain.solmem/lib/LibUint256Matrix.sol";
import {Sentinel, LibStackSentinel} from "rain.solmem/lib/LibStackSentinel.sol";
import {EncodedDispatch, LibEncodedDispatch} from "rain.interpreter/src/lib/caller/LibEncodedDispatch.sol";
import {ICloneableV2, ICLONEABLE_V2_SUCCESS} from "rain.factory/src/interface/ICloneableV2.sol";
import {
    IFlowERC721V4,
    FlowERC721IOV1,
    SignedContextV1,
    FlowERC721ConfigV2,
    ERC721SupplyChange,
    FLOW_ERC721_TOKEN_URI_MIN_OUTPUTS,
    FLOW_ERC721_TOKEN_URI_MAX_OUTPUTS,
    FLOW_ERC721_HANDLE_TRANSFER_MIN_OUTPUTS,
    FLOW_ERC721_HANDLE_TRANSFER_MAX_OUTPUTS,
    FLOW_ERC721_TOKEN_URI_ENTRYPOINT,
    FLOW_ERC721_HANDLE_TRANSFER_ENTRYPOINT,
    FLOW_ERC721_MIN_FLOW_SENTINELS
} from "../../interface/unstable/IFlowERC721V4.sol";
import {LibBytecode} from "lib/rain.interpreter/src/lib/bytecode/LibBytecode.sol";
import {SourceIndex} from "rain.interpreter/src/interface/IInterpreterV1.sol";
import {LibFlow} from "../../lib/LibFlow.sol";
import {
    FlowCommon,
    DeployerDiscoverableMetaV2ConstructionConfig,
    LibContext,
    ERC1155Receiver
} from "../../abstract/FlowCommon.sol";
import {Evaluable, DEFAULT_STATE_NAMESPACE} from "rain.interpreter/src/lib/caller/LibEvaluable.sol";
import {IInterpreterV1} from "rain.interpreter/src/interface/IInterpreterV1.sol";
import {IInterpreterStoreV1} from "rain.interpreter/src/interface/IInterpreterStoreV1.sol";
import {Pointer} from "rain.solmem/lib/LibPointer.sol";
import {RAIN_FLOW_SENTINEL, BurnerNotOwner} from "../../interface/unstable/IFlowERC721V4.sol";

/// @dev The hash of the meta data expected to be passed to `FlowCommon`'s
/// constructor.
bytes32 constant CALLER_META_HASH = bytes32(0xf0003e81ff90467c9933f3ac68db3ca49df8b30ab83a0b88e1ed8381ed28fdd6);

/// @title FlowERC721
/// See `IFlowERC721V4` for documentation.
contract FlowERC721 is ICloneableV2, IFlowERC721V4, FlowCommon, ERC721 {
    using LibUint256Matrix for uint256[];
    using LibUint256Array for uint256[];
    using LibStackSentinel for Pointer;

    /// @dev True if we need to eval `handleTransfer` on every transfer. For many
    /// tokens this will be false, so we don't want to invoke the external
    /// interpreter call just to cause a noop.
    bool private sEvalHandleTransfer;

    /// @dev True if we need to eval `tokenURI` to build the token URI. For many
    /// tokens this will be false, so we don't want to invoke the external
    /// interpreter call just to cause a noop.
    bool private sEvalTokenURI;

    /// @dev The evaluable that contains the entrypoints for `handleTransfer` and
    /// `tokenURI`. This is only set if `sEvalHandleTransfer` or `sEvalTokenURI`
    /// is true.
    Evaluable internal sEvaluable;

    /// @dev The base URI for all token URIs. This is set during initialization
    /// and cannot be changed. The token URI evaluable can be used for dynamic
    /// token URIs from the base URI.
    string private sBaseURI;

    /// Forwards the `FlowCommon` constructor arguments to the `FlowCommon`.
    constructor(DeployerDiscoverableMetaV2ConstructionConfig memory config) FlowCommon(CALLER_META_HASH, config) {}

    /// Needed here to fix Open Zeppelin implementing `supportsInterface` on
    /// multiple base contracts.
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC721, ERC1155Receiver)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    /// Overloaded typed initialize function MUST revert with this error.
    /// As per `ICloneableV2` interface.
    function initialize(FlowERC721ConfigV2 memory) external pure {
        revert InitializeSignatureFn();
    }

    /// @inheritdoc ICloneableV2
    function initialize(bytes calldata data) external initializer returns (bytes32) {
        FlowERC721ConfigV2 memory flowERC721Config = abi.decode(data, (FlowERC721ConfigV2));
        emit Initialize(msg.sender, flowERC721Config);
        __ERC721_init(flowERC721Config.name, flowERC721Config.symbol);
        sBaseURI = flowERC721Config.baseURI;

        // Set state before external calls here.
        uint256 sourceCount = LibBytecode.sourceCount(flowERC721Config.evaluableConfig.bytecode);
        bool evalHandleTransfer = sourceCount > 0
            && LibBytecode.sourceOpsCount(
                flowERC721Config.evaluableConfig.bytecode, SourceIndex.unwrap(FLOW_ERC721_HANDLE_TRANSFER_ENTRYPOINT)
            ) > 0;
        bool evalTokenURI = sourceCount > 1
            && LibBytecode.sourceOpsCount(
                flowERC721Config.evaluableConfig.bytecode, SourceIndex.unwrap(FLOW_ERC721_TOKEN_URI_ENTRYPOINT)
            ) > 0;
        sEvalHandleTransfer = evalHandleTransfer;
        sEvalTokenURI = evalTokenURI;

        flowCommonInit(flowERC721Config.flowConfig, FLOW_ERC721_MIN_FLOW_SENTINELS);

        if (evalHandleTransfer) {
            // Include the token URI min outputs if we expect to eval it,
            // otherwise only include the handle transfer min outputs.
            uint256[] memory minOutputs = evalTokenURI
                ? LibUint256Array.arrayFrom(FLOW_ERC721_HANDLE_TRANSFER_MIN_OUTPUTS, FLOW_ERC721_TOKEN_URI_MIN_OUTPUTS)
                : LibUint256Array.arrayFrom(FLOW_ERC721_HANDLE_TRANSFER_MIN_OUTPUTS);

            (IInterpreterV1 interpreter, IInterpreterStoreV1 store, address expression) = flowERC721Config
                .evaluableConfig
                .deployer
                .deployExpression(
                flowERC721Config.evaluableConfig.bytecode, flowERC721Config.evaluableConfig.constants, minOutputs
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

    /// Overrides the Open Zeppelin `_baseURI` hook to return the base URI set
    /// during initialization.
    /// @inheritdoc ERC721
    function _baseURI() internal view virtual override returns (string memory) {
        return sBaseURI;
    }

    /// Overrides the Open Zeppelin `tokenURI` function to return the token URI
    /// calculated by the token URI evaluable. Currently the token URI evaluable
    /// can only return a single token ID value, and the token URI is built from
    /// that according to default Open Zeppelin logic. If the token URI evaluable
    /// is not set, then the default Open Zeppelin logic is used with the token
    /// ID passed in.
    /// @inheritdoc ERC721
    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        if (sEvalTokenURI) {
            Evaluable memory evaluable = sEvaluable;
            (uint256[] memory stack, uint256[] memory kvs) = evaluable.interpreter.eval(
                evaluable.store,
                DEFAULT_STATE_NAMESPACE,
                LibEncodedDispatch.encode(
                    evaluable.expression, FLOW_ERC721_TOKEN_URI_ENTRYPOINT, FLOW_ERC721_TOKEN_URI_MAX_OUTPUTS
                ),
                LibContext.build(LibUint256Array.arrayFrom(tokenId).matrixFrom(), new SignedContextV1[](0))
            );
            // @todo it would be nice if we could do something with the kvs here,
            // but the interface is view.
            (kvs);
            tokenId = stack[0];
        }

        return super.tokenURI(tokenId);
    }

    /// @inheritdoc IFlowERC721V4
    function stackToFlow(uint256[] memory stack) external pure virtual override returns (FlowERC721IOV1 memory) {
        return _stackToFlow(stack.dataPointer(), stack.endPointer());
    }

    /// @inheritdoc IFlowERC721V4
    function flow(Evaluable memory evaluable, uint256[] memory callerContext, SignedContextV1[] memory signedContexts)
        external
        virtual
        returns (FlowERC721IOV1 memory)
    {
        return _flow(evaluable, callerContext, signedContexts);
    }

    /// Exposes the Open Zeppelin `_afterTokenTransfer` hook as an evaluable
    /// entrypoint so that the deployer of the token can use it to implement
    /// custom transfer logic. The stack is ignored, so if the expression author
    /// wants to prevent some kind of transfer, they can just revert within the
    /// expression evaluation.
    /// @inheritdoc ERC721
    function _afterTokenTransfer(address from, address to, uint256 tokenId, uint256 batchSize)
        internal
        virtual
        override
    {
        unchecked {
            super._afterTokenTransfer(from, to, tokenId, batchSize);

            // Mint and burn access MUST be handled by flow.
            // HANDLE_TRANSFER will only restrict subsequent transfers.
            if (sEvalHandleTransfer && !(from == address(0) || to == address(0))) {
                Evaluable memory evaluable = sEvaluable;
                (uint256[] memory stack, uint256[] memory kvs) = evaluable.interpreter.eval(
                    evaluable.store,
                    DEFAULT_STATE_NAMESPACE,
                    LibEncodedDispatch.encode(
                        evaluable.expression,
                        FLOW_ERC721_HANDLE_TRANSFER_ENTRYPOINT,
                        FLOW_ERC721_HANDLE_TRANSFER_MAX_OUTPUTS
                    ),
                    LibContext.build(
                        // Transfer information.
                        // Does NOT include `batchSize` because handle
                        // transfer is NOT called for mints.
                        LibUint256Array.arrayFrom(uint256(uint160(from)), uint256(uint160(to)), tokenId).matrixFrom(),
                        new SignedContextV1[](0)
                    )
                );
                (stack);
                if (kvs.length > 0) {
                    evaluable.store.set(DEFAULT_STATE_NAMESPACE, kvs);
                }
            }
        }
    }

    /// Wraps the standard `LibFlow.stackToFlow` with the additional logic to
    /// convert the stack to a `FlowERC721IOV1` struct. This involves consuming
    /// the mints and burns from the stack as additional sentinel separated
    /// tuples. The mints are consumed first, then the burns, then the remaining
    /// stack is converted to a flow as normal.
    /// @param stackBottom The bottom of the stack.
    /// @param stackTop The top of the stack.
    /// @return flowERC721IO The `FlowERC721IOV1` representation of the stack.
    function _stackToFlow(Pointer stackBottom, Pointer stackTop) internal pure returns (FlowERC721IOV1 memory) {
        ERC721SupplyChange[] memory mints;
        ERC721SupplyChange[] memory burns;
        Pointer tuplesPointer;

        // mints
        // https://github.com/crytic/slither/issues/2126
        //slither-disable-next-line unused-return
        (stackTop, tuplesPointer) = stackBottom.consumeSentinelTuples(stackTop, RAIN_FLOW_SENTINEL, 2);
        assembly ("memory-safe") {
            mints := tuplesPointer
        }
        // burns
        // https://github.com/crytic/slither/issues/2126
        //slither-disable-next-line unused-return
        (stackTop, tuplesPointer) = stackBottom.consumeSentinelTuples(stackTop, RAIN_FLOW_SENTINEL, 2);
        assembly ("memory-safe") {
            burns := tuplesPointer
        }

        return FlowERC721IOV1(mints, burns, LibFlow.stackToFlow(stackBottom, stackTop));
    }

    /// Wraps the standard `LibFlow.flow` with the additional logic to handle
    /// self minting and burning. This involves consuming the mints and burns
    /// from the stack as additional sentinel separated tuples. The mints are
    /// consumed first, then the burns, then the remaining stack is converted to
    /// a flow as normal.
    function _flow(Evaluable memory evaluable, uint256[] memory callerContext, SignedContextV1[] memory signedContexts)
        internal
        virtual
        nonReentrant
        returns (FlowERC721IOV1 memory)
    {
        unchecked {
            (Pointer stackBottom, Pointer stackTop, uint256[] memory kvs) =
                _flowStack(evaluable, callerContext, signedContexts);
            FlowERC721IOV1 memory flowERC721IO = _stackToFlow(stackBottom, stackTop);
            for (uint256 i = 0; i < flowERC721IO.mints.length; i++) {
                _safeMint(flowERC721IO.mints[i].account, flowERC721IO.mints[i].id);
            }
            for (uint256 i = 0; i < flowERC721IO.burns.length; i++) {
                uint256 burnId = flowERC721IO.burns[i].id;
                if (ERC721.ownerOf(burnId) != flowERC721IO.burns[i].account) {
                    revert BurnerNotOwner();
                }
                _burn(burnId);
            }
            LibFlow.flow(flowERC721IO.flow, evaluable.store, kvs);
            return flowERC721IO;
        }
    }
}
