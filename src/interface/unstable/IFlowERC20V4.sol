// SPDX-License-Identifier: CAL
pragma solidity ^0.8.18;

import {SignedContextV1} from "rain.interpreter/src/interface/IInterpreterCallerV2.sol";
import {Evaluable, EvaluableConfigV2} from "rain.interpreter/src/lib/caller/LibEvaluable.sol";
import {Sentinel} from "rain.solmem/lib/LibStackSentinel.sol";
import {
    FlowERC20IOV1,
    ERC20SupplyChange,
    FLOW_ERC20_HANDLE_TRANSFER_ENTRYPOINT,
    FLOW_ERC20_HANDLE_TRANSFER_MIN_OUTPUTS,
    FLOW_ERC20_HANDLE_TRANSFER_MAX_OUTPUTS
} from "../IFlowERC20V3.sol";
import {RAIN_FLOW_SENTINEL} from "./IFlowV4.sol";

/// Constructor config.
/// @param name As per Open Zeppelin `ERC20Upgradeable`.
/// @param symbol As per Open Zeppelin `ERC20Upgradeable`.
/// @param evaluableConfig The `EvaluableConfigV2` to use to build the
/// `evaluable` that can be used to evaluate `handleTransfer`.
/// @param flowConfig The `EvaluableConfigV2[]` to use to build the
/// `evaluable`s for all the flows, including self minting and burning.
struct FlowERC20ConfigV2 {
    string name;
    string symbol;
    EvaluableConfigV2 evaluableConfig;
    EvaluableConfigV2[] flowConfig;
}

/// @title IFlowERC20V4
/// Conceptually identical to `IFlowV4`, but with the addition of th
interface IFlowERC20V4 {
    event Initialize(address sender, FlowERC20ConfigV2 config);

    function stackToFlow(uint256[] memory stack) external pure returns (FlowERC20IOV1 memory flowERC20IO);

    function flow(
        Evaluable calldata evaluable,
        uint256[] calldata callerContext,
        SignedContextV1[] calldata signedContexts
    ) external returns (FlowERC20IOV1 calldata flowERC20IO);
}
