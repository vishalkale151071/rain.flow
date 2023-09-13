// SPDX-License-Identifier: CAL
pragma solidity =0.8.19;

import {LibUint256Array} from "rain.solmem/lib/LibUint256Array.sol";
import {Pointer} from "rain.solmem/lib/LibPointer.sol";
import {IInterpreterCallerV2} from "rain.interpreter/src/interface/IInterpreterCallerV2.sol";
import {LibEncodedDispatch} from "rain.interpreter/src/lib/caller/LibEncodedDispatch.sol";
import {LibContext} from "rain.interpreter/src/lib/caller/LibContext.sol";
import {UnregisteredFlow} from "../interface/unstable/IFlowV4.sol";
import {
    DeployerDiscoverableMetaV2,
    DeployerDiscoverableMetaV2ConstructionConfig
} from "rain.interpreter/src/abstract/DeployerDiscoverableMetaV2.sol";
import {
    LibEvaluable,
    Evaluable,
    EvaluableConfigV2,
    DEFAULT_STATE_NAMESPACE
} from "rain.interpreter/src/lib/caller/LibEvaluable.sol";
import {SourceIndex, IInterpreterV1} from "rain.interpreter/src/interface/IInterpreterV1.sol";
import {IInterpreterStoreV1} from "rain.interpreter/src/interface/IInterpreterStoreV1.sol";

import {MulticallUpgradeable as Multicall} from
    "openzeppelin-contracts-upgradeable/contracts/utils/MulticallUpgradeable.sol";
import {ERC721HolderUpgradeable as ERC721Holder} from
    "openzeppelin-contracts-upgradeable/contracts/token/ERC721/utils/ERC721HolderUpgradeable.sol";
import {
    ERC1155HolderUpgradeable as ERC1155Holder,
    ERC1155ReceiverUpgradeable as ERC1155Receiver
} from "openzeppelin-contracts-upgradeable/contracts/token/ERC1155/utils/ERC1155HolderUpgradeable.sol";
import {ReentrancyGuardUpgradeable as ReentrancyGuard} from
    "openzeppelin-contracts-upgradeable/contracts/security/ReentrancyGuardUpgradeable.sol";

/// Thrown when the min outputs for a flow is fewer than the sentinels.
/// This is always an implementation bug as the min outputs and sentinel count
/// should both be compile time constants.
/// @param flowMinOutputs The min outputs for the flow.
error BadMinStackLength(uint256 flowMinOutputs);

/// @dev The number of sentinels required by `FlowCommon`. An evaluable can never
/// have fewer minimum outputs than required sentinels.
uint256 constant MIN_FLOW_SENTINELS = 3;

/// @dev The entrypoint for a flow is always `0` because each flow has its own
/// evaluable with its own entrypoint. Running multiple flows involves evaluating
/// several expressions in sequence.
SourceIndex constant FLOW_ENTRYPOINT = SourceIndex.wrap(0);
/// @dev There is no maximum number of outputs for a flow. Pragmatically gas will
/// limit the number of outputs well before this limit is reached.
uint16 constant FLOW_MAX_OUTPUTS = type(uint16).max;

/// @dev Any non-zero value indicates that the flow is registered.
uint256 constant FLOW_IS_REGISTERED = 1;

/// @dev Zero indicates that the flow is not registered.
uint256 constant FLOW_IS_NOT_REGISTERED = 0;

/// @title FlowCommon
/// @notice Common functionality for flows. Largely handles the evaluable
/// registration and dispatch. Also implementes the necessary interfaces for
/// a smart contract to receive ERC721 and ERC1155 tokens.
///
/// Flow contracts are expected to be deployed via. a proxy/factory as clones
/// of an implementation contract. This makes flows cheap to deploy and every
/// flow contract can be initialized with a different set of flows. This gives
/// strong guarantees that the flow contract is only capable of evaluating
/// registered flows, and that individual flow contracts cannot collide state
/// with each other, given a correctly implemented interpreter store. Combining
/// proxies with rainlang gives us a very powerful and flexible system for
/// composing flows without significant gas overhead. Typically a flow contract
/// deployment will cost well under 1M gas, which is very cheap for bespoke
/// logic, without significant runtime overheads. This allows for new UX patterns
/// where users can cheaply create many different tools such as NFT mints,
/// auctions, escrows, etc. and aim to horizontally scale rather than design
/// monolithic protocols.
///
/// This does NOT implement the preview and flow logic directly because each
/// flow implementation has different requirements for the mint and burn logic
/// of the flow tokens. In the future, this may be refactored so that a single
/// flow contract can handle all flows.
///
/// `FlowCommon` is `Multicall` so it is NOT compatible with receiving ETH. This
/// is because `Multicall` uses `delegatecall` in a loop which reuses `msg.value`
/// for each loop iteration, effectively "double spending" the ETH it receives.
/// This is a known issue with `Multicall` so in the future, we may refactor
/// `FlowCommon` to not use `Multicall` and instead implement flow batching
/// directly in the flow contracts.
abstract contract FlowCommon is
    ERC721Holder,
    ERC1155Holder,
    Multicall,
    ReentrancyGuard,
    IInterpreterCallerV2,
    DeployerDiscoverableMetaV2
{
    using LibUint256Array for uint256[];
    using LibEvaluable for Evaluable;

    /// @dev This mapping tracks all flows that are registered at initialization.
    /// This is used to ensure that only registered flows are evaluated.
    /// Inheriting contracts MUST check this mapping before evaluating a flow,
    /// else anons can deploy their own evaluable and drain the contract.
    /// `isRegistered` will be set to `FLOW_IS_REGISTERED` for each registered
    /// flow.
    mapping(bytes32 evaluableHash => uint256 isRegistered) internal registeredFlows;

    /// This event is emitted when a flow is registered at initialization.
    /// @param sender The address that registered the flow.
    /// @param evaluable The evaluable of the flow that was registered. The hash
    /// of this evaluable is used as the key in `registeredFlows` so users MUST
    /// provide the same evaluable when they evaluate the flow.
    event FlowInitialized(address sender, Evaluable evaluable);

    /// Forwards config to `DeployerDiscoverableMetaV2` and disables
    /// initializers. The initializers are disabled because inheriting contracts
    /// are expected to implement some kind of initialization logic that is
    /// compatible with cloning via. proxy/factory. Disabling initializers
    /// in the implementation contract forces that the only way to initialize
    /// the contract is via. a proxy, which should also strongly encourage
    /// patterns that _atomically_ clone and initialize via. some factory.
    /// @param metaHash As per `DeployerDiscoverableMetaV2`.
    /// @param config As per `DeployerDiscoverableMetaV2`.
    constructor(bytes32 metaHash, DeployerDiscoverableMetaV2ConstructionConfig memory config)
        DeployerDiscoverableMetaV2(metaHash, config)
    {
        _disableInitializers();
    }

    /// Common initialization logic for inheriting contracts. This MUST be
    /// called by inheriting contracts in their initialization logic (and only).
    /// @param evaluableConfigs The evaluable configs to register at
    /// initialization. Each of these represents a flow that defines valid token
    /// movements at runtime for the inheriting contract.
    /// @param flowMinOutputs The minimum number of outputs for each flow. All
    /// flows share the same minimum number of outputs for simplicity.
    function flowCommonInit(EvaluableConfigV2[] memory evaluableConfigs, uint256 flowMinOutputs)
        internal
        onlyInitializing
    {
        unchecked {
            // First dispatch all the Open Zeppelin initializers.
            __ERC721Holder_init();
            __ERC1155Holder_init();
            __Multicall_init();
            __ReentrancyGuard_init();

            // This should never fail because the min outputs should always be
            // at least the number of sentinels, and is compile time constant.
            // It's a cheap sanity check on the downstream implementation.
            if (flowMinOutputs < MIN_FLOW_SENTINELS) {
                revert BadMinStackLength(flowMinOutputs);
            }

            EvaluableConfigV2 memory config;
            Evaluable memory evaluable;
            // Every evaluable MUST deploy cleanly (e.g. pass integrity checks)
            // otherwise the entire initialization will fail.
            for (uint256 i = 0; i < evaluableConfigs.length; ++i) {
                config = evaluableConfigs[i];
                // Well behaved deployers SHOULD NOT be reentrant into the flow
                // contract. It is up to the EOA that is initializing this
                // flow contract to select a deployer that is trustworthy.
                // Reentrancy is just one of many ways that a malicious deployer
                // can cause problems, and it's probably the least of your
                // worries if you're using a malicious deployer.
                (IInterpreterV1 interpreter, IInterpreterStoreV1 store, address expression) = config
                    .deployer
                    .deployExpression(config.bytecode, config.constants, LibUint256Array.arrayFrom(flowMinOutputs));
                evaluable = Evaluable(interpreter, store, expression);
                // There's no way to set this mapping before the external
                // contract call because the output of the external contract
                // call is used to build the evaluable that we're registering.
                // Even if we could modify state before making external calls,
                // it probably wouldn't make sense to be finalisating the
                // registration of a flow before we know that the flow is
                // deployable according to the deployer's own integrity checks.
                //slither-disable-next-line reentrancy-benign
                registeredFlows[evaluable.hash()] = FLOW_IS_REGISTERED;
                // There's no way to emit this event before the external contract
                // call because the output of the external contract call is
                // the input to the event.
                //slither-disable-next-line reentrancy-events
                emit FlowInitialized(msg.sender, evaluable);
            }
        }
    }

    /// Standard evaluation logic for flows. This includes critical guards to
    /// ensure that only registered flows are evaluated. This is the only
    /// function that inheriting contracts should call to evaluate flows.
    /// The start and end pointers to the stack are returned so that inheriting
    /// contracts can easily scan the stack for sentinels, which is the expected
    /// pattern to determine what token moments are required.
    /// @param evaluable The evaluable to evaluate.
    /// @param context The context to evaluate the evaluable with. The inheriting
    /// contract is expected to provide the correct context for the flow,
    /// including checking signatures etc.
    function flowStack(Evaluable memory evaluable, uint256[][] memory context)
        internal
        view
        returns (Pointer, Pointer, uint256[] memory)
    {
        // Refuse to evaluate unregistered flows.
        {
            bytes32 evaluableHash = evaluable.hash();
            if (registeredFlows[evaluableHash] == FLOW_IS_NOT_REGISTERED) {
                revert UnregisteredFlow(evaluableHash);
            }
        }

        (uint256[] memory stack, uint256[] memory kvs) = evaluable.interpreter.eval(
            evaluable.store,
            DEFAULT_STATE_NAMESPACE,
            LibEncodedDispatch.encode(evaluable.expression, FLOW_ENTRYPOINT, FLOW_MAX_OUTPUTS),
            context
        );
        return (stack.dataPointer(), stack.endPointer(), kvs);
    }
}
