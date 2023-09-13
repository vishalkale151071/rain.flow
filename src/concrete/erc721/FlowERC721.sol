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
    ERC721SupplyChange
} from "../../interface/unstable/IFlowERC721V4.sol";
import {LibBytecode} from "lib/rain.interpreter/src/lib/bytecode/LibBytecode.sol";
import {SourceIndex} from "rain.interpreter/src/interface/IInterpreterV1.sol";
import {LibFlow, SENTINEL_HIGH_BITS} from "../../lib/LibFlow.sol";
import {
    FlowCommon,
    DeployerDiscoverableMetaV2ConstructionConfig,
    LibContext,
    MIN_FLOW_SENTINELS,
    ERC1155Receiver
} from "../../abstract/FlowCommon.sol";
import {Evaluable, DEFAULT_STATE_NAMESPACE} from "rain.interpreter/src/lib/caller/LibEvaluable.sol";
import {IInterpreterV1} from "rain.interpreter/src/interface/IInterpreterV1.sol";
import {IInterpreterStoreV1} from "rain.interpreter/src/interface/IInterpreterStoreV1.sol";
import {Pointer} from "rain.solmem/lib/LibPointer.sol";

/// Thrown when burner of tokens is not the owner of tokens.
error BurnerNotOwner();

Sentinel constant RAIN_FLOW_ERC721_SENTINEL =
    Sentinel.wrap(uint256(keccak256(bytes("RAIN_FLOW_ERC721_SENTINEL")) | SENTINEL_HIGH_BITS));

bytes32 constant CALLER_META_HASH = bytes32(0x7f7944a4b89741668c06a27ffde94e19be970cd0506786de91aee01c2893d4ef);

SourceIndex constant HANDLE_TRANSFER_ENTRYPOINT = SourceIndex.wrap(0);
SourceIndex constant TOKEN_URI_ENTRYPOINT = SourceIndex.wrap(1);
uint256 constant HANDLE_TRANSFER_MIN_OUTPUTS = 0;
uint256 constant TOKEN_URI_MIN_OUTPUTS = 1;
uint16 constant HANDLE_TRANSFER_MAX_OUTPUTS = 0;
uint16 constant TOKEN_URI_MAX_OUTPUTS = 1;

/// @title FlowERC721
contract FlowERC721 is ICloneableV2, IFlowERC721V4, FlowCommon, ERC721 {
    using LibUint256Matrix for uint256[];
    using LibStackSentinel for Pointer;

    bool private sEvalHandleTransfer;
    bool private sEvalTokenURI;
    Evaluable internal sEvaluable;
    string private sBaseURI;

    constructor(DeployerDiscoverableMetaV2ConstructionConfig memory config) FlowCommon(CALLER_META_HASH, config) {}

    /// @inheritdoc ICloneableV2
    function initialize(bytes calldata data) external initializer returns (bytes32) {
        FlowERC721ConfigV2 memory flowERC721Config = abi.decode(data, (FlowERC721ConfigV2));
        emit Initialize(msg.sender, flowERC721Config);
        __ERC721_init(flowERC721Config.name, flowERC721Config.symbol);
        sBaseURI = flowERC721Config.baseURI;

        // Set state before external calls here.
        uint256 sourceCount = LibBytecode.sourceCount(flowERC721Config.evaluableConfig.bytecode);
        bool evalHandleTransfer = sourceCount > 0
            && LibBytecode.sourceOpsLength(
                flowERC721Config.evaluableConfig.bytecode, SourceIndex.unwrap(HANDLE_TRANSFER_ENTRYPOINT)
            ) > 0;
        bool evalTokenURI = sourceCount > 1
            && LibBytecode.sourceOpsLength(
                flowERC721Config.evaluableConfig.bytecode, SourceIndex.unwrap(TOKEN_URI_ENTRYPOINT)
            ) > 0;
        sEvalHandleTransfer = evalHandleTransfer;
        sEvalTokenURI = evalTokenURI;

        flowCommonInit(flowERC721Config.flowConfig, MIN_FLOW_SENTINELS + 2);

        if (evalHandleTransfer) {
            // Include the token URI min outputs if we expect to eval it,
            // otherwise only include the handle transfer min outputs.
            uint256[] memory minOutputs = evalTokenURI
                ? LibUint256Array.arrayFrom(HANDLE_TRANSFER_MIN_OUTPUTS, TOKEN_URI_MIN_OUTPUTS)
                : LibUint256Array.arrayFrom(HANDLE_TRANSFER_MIN_OUTPUTS);

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

    function _baseURI() internal view virtual override returns (string memory) {
        return sBaseURI;
    }

    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        if (sEvalTokenURI) {
            Evaluable memory evaluable = sEvaluable;
            (uint256[] memory stack, uint256[] memory kvs) = evaluable.interpreter.eval(
                evaluable.store,
                DEFAULT_STATE_NAMESPACE,
                _dispatchTokenURI(evaluable.expression),
                LibContext.build(LibUint256Array.arrayFrom(tokenId).matrixFrom(), new SignedContextV1[](0))
            );
            // @todo it would be nice if we could do something with the kvs here,
            // but the interface is view.
            (kvs);
            tokenId = stack[0];
        }

        return super.tokenURI(tokenId);
    }

    function _dispatchHandleTransfer(address expression) internal pure returns (EncodedDispatch) {
        return LibEncodedDispatch.encode(expression, HANDLE_TRANSFER_ENTRYPOINT, HANDLE_TRANSFER_MAX_OUTPUTS);
    }

    function _dispatchTokenURI(address expression) internal pure returns (EncodedDispatch) {
        return LibEncodedDispatch.encode(expression, TOKEN_URI_ENTRYPOINT, TOKEN_URI_MAX_OUTPUTS);
    }

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
                    _dispatchHandleTransfer(evaluable.expression),
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

    function _previewFlow(Evaluable memory evaluable, uint256[][] memory context)
        internal
        view
        returns (FlowERC721IOV1 memory, uint256[] memory)
    {
        ERC721SupplyChange[] memory mints;
        ERC721SupplyChange[] memory burns;
        Pointer tuplesPointer;

        (Pointer stackBottom, Pointer stackTop, uint256[] memory kvs) = flowStack(evaluable, context);
        // mints
        // https://github.com/crytic/slither/issues/2126
        //slither-disable-next-line unused-return
        (stackTop, tuplesPointer) = stackBottom.consumeSentinelTuples(stackTop, RAIN_FLOW_ERC721_SENTINEL, 2);
        assembly ("memory-safe") {
            mints := tuplesPointer
        }
        // burns
        // https://github.com/crytic/slither/issues/2126
        //slither-disable-next-line unused-return
        (stackTop, tuplesPointer) = stackBottom.consumeSentinelTuples(stackTop, RAIN_FLOW_ERC721_SENTINEL, 2);
        assembly ("memory-safe") {
            burns := tuplesPointer
        }
        return (FlowERC721IOV1(mints, burns, LibFlow.stackToFlow(stackBottom, stackTop)), kvs);
    }

    function _flow(Evaluable memory evaluable, uint256[] memory callerContext, SignedContextV1[] memory signedContexts)
        internal
        virtual
        nonReentrant
        returns (FlowERC721IOV1 memory)
    {
        unchecked {
            uint256[][] memory context = LibContext.build(callerContext.matrixFrom(), signedContexts);
            emit Context(msg.sender, context);
            (FlowERC721IOV1 memory flowIO, uint256[] memory kvs) = _previewFlow(evaluable, context);
            for (uint256 i = 0; i < flowIO.mints.length; i++) {
                _safeMint(flowIO.mints[i].account, flowIO.mints[i].id);
            }
            for (uint256 i = 0; i < flowIO.burns.length; i++) {
                uint256 burnId = flowIO.burns[i].id;
                if (ERC721.ownerOf(burnId) != flowIO.burns[i].account) {
                    revert BurnerNotOwner();
                }
                _burn(burnId);
            }
            LibFlow.flow(flowIO.flow, evaluable.store, kvs);
            return flowIO;
        }
    }

    function previewFlow(
        Evaluable memory evaluable,
        uint256[] memory callerContext,
        SignedContextV1[] memory signedContexts
    ) external view virtual returns (FlowERC721IOV1 memory) {
        uint256[][] memory context = LibContext.build(callerContext.matrixFrom(), signedContexts);
        (FlowERC721IOV1 memory flowERC721IO,) = _previewFlow(evaluable, context);
        return flowERC721IO;
    }

    function flow(Evaluable memory evaluable, uint256[] memory callerContext, SignedContextV1[] memory signedContexts)
        external
        virtual
        returns (FlowERC721IOV1 memory)
    {
        return _flow(evaluable, callerContext, signedContexts);
    }
}
