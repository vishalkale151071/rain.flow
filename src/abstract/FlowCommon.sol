// SPDX-License-Identifier: CAL
pragma solidity =0.8.19;

import "../lib/LibFlow.sol";
import "rain.interpreter/src/interface/IInterpreterCallerV2.sol";
import "rain.interpreter/src/interface/IExpressionDeployerV1.sol";
import "rain.interpreter/src/interface/IInterpreterV1.sol";
import "rain.interpreter/src/lib/caller/LibEncodedDispatch.sol";
import "rain.interpreter/src/lib/caller/LibContext.sol";
import "rain.interpreter/src/abstract/DeployerDiscoverableMetaV2.sol";
import "rain.interpreter/src/lib/caller/LibEvaluable.sol";

import {MulticallUpgradeable as Multicall} from
    "openzeppelin-contracts-upgradeable/contracts/utils/MulticallUpgradeable.sol";
import {ERC721HolderUpgradeable as ERC721Holder} from
    "openzeppelin-contracts-upgradeable/contracts/token/ERC721/utils/ERC721HolderUpgradeable.sol";
import {ERC1155HolderUpgradeable as ERC1155Holder} from
    "openzeppelin-contracts-upgradeable/contracts/token/ERC1155/utils/ERC1155HolderUpgradeable.sol";

/// Thrown when the flow being evaluated is unregistered.
/// @param unregisteredHash Hash of the unregistered flow.
error UnregisteredFlow(bytes32 unregisteredHash);

/// Thrown when the min outputs for a flow is fewer than the sentinels.
error BadMinStackLength(uint256 flowMinOutputs_);

uint256 constant FLAG_COLUMN_FLOW_ID = 0;
uint256 constant FLAG_ROW_FLOW_ID = 0;
uint256 constant FLAG_COLUMN_FLOW_TIME = 0;
uint256 constant FLAG_ROW_FLOW_TIME = 2;

uint256 constant MIN_FLOW_SENTINELS = 3;

SourceIndex constant FLOW_ENTRYPOINT = SourceIndex.wrap(0);
uint16 constant FLOW_MAX_OUTPUTS = type(uint16).max;

contract FlowCommon is ERC721Holder, ERC1155Holder, Multicall, IInterpreterCallerV2, DeployerDiscoverableMetaV2 {
    using LibStackPointer for Pointer;
    using LibStackPointer for uint256[];
    using LibUint256Array for uint256;
    using LibUint256Array for uint256[];
    using LibEvaluable for Evaluable;

    /// Evaluable hash => is registered
    mapping(bytes32 => uint256) internal registeredFlows;

    event FlowInitialized(address sender, Evaluable evaluable);

    constructor(bytes32 metaHash, DeployerDiscoverableMetaV2ConstructionConfig memory config)
        DeployerDiscoverableMetaV2(metaHash, config)
    {
        _disableInitializers();
    }

    function flowCommonInit(EvaluableConfigV2[] memory evaluableConfigs, uint256 flowMinOutputs)
        internal
        onlyInitializing
    {
        unchecked {
            __ERC721Holder_init();
            __ERC1155Holder_init();
            __Multicall_init();
            if (flowMinOutputs < MIN_FLOW_SENTINELS) {
                revert BadMinStackLength(flowMinOutputs);
            }
            EvaluableConfigV2 memory config;
            Evaluable memory evaluable;
            for (uint256 i = 0; i < evaluableConfigs.length; ++i) {
                config = evaluableConfigs[i];
                (IInterpreterV1 interpreter, IInterpreterStoreV1 store, address expression) = config
                    .deployer
                    .deployExpression(config.bytecode, config.constants, LibUint256Array.arrayFrom(flowMinOutputs));
                evaluable = Evaluable(interpreter, store, expression);
                registeredFlows[evaluable.hash()] = 1;
                emit FlowInitialized(msg.sender, evaluable);
            }
        }
    }

    function _flowDispatch(address expression_) internal pure returns (EncodedDispatch) {
        return LibEncodedDispatch.encode(expression_, FLOW_ENTRYPOINT, FLOW_MAX_OUTPUTS);
    }

    modifier onlyRegisteredEvaluable(Evaluable memory evaluable_) {
        bytes32 hash_ = evaluable_.hash();
        if (registeredFlows[hash_] == 0) {
            revert UnregisteredFlow(hash_);
        }
        _;
    }

    function flowStack(Evaluable memory evaluable_, uint256[][] memory context_)
        internal
        view
        onlyRegisteredEvaluable(evaluable_)
        returns (Pointer, Pointer, uint256[] memory)
    {
        (uint256[] memory stack_, uint256[] memory kvs_) = evaluable_.interpreter.eval(
            evaluable_.store, DEFAULT_STATE_NAMESPACE, _flowDispatch(evaluable_.expression), context_
        );
        return (stack_.dataPointer(), stack_.endPointer(), kvs_);
    }
}
