// SPDX-License-Identifier: CAL
pragma solidity =0.8.18;

import "rain.interface.interpreter/LibContext.sol";
import "rain.interface.interpreter/LibEvaluable.sol";

import "./IFlowV1.sol";

struct ERC20SupplyChange {
    address account;
    uint256 amount;
}

struct FlowERC20IO {
    ERC20SupplyChange[] mints;
    ERC20SupplyChange[] burns;
    FlowTransfer flow;
}

/// Constructor config.
/// @param Constructor config for the ERC20 token minted according to flow
/// schedule in `flow`.
/// @param Constructor config for the `ImmutableSource` that defines the
/// emissions schedule for claiming.
struct FlowERC20Config {
    string name;
    string symbol;
    EvaluableConfig evaluableConfig;
    EvaluableConfig[] flowConfig;
}

interface IFlowERC20V1 {
    /// Contract has initialized.
    /// @param sender `msg.sender` initializing the contract (factory).
    /// @param config All initialized config.
    event Initialize(address sender, FlowERC20Config config);

    function previewFlow(
        Evaluable calldata evaluable,
        uint256[] calldata callerContext,
        SignedContext[] calldata signedContexts
    ) external view returns (FlowERC20IO calldata);

    function flow(Evaluable calldata evaluable, uint256[] calldata callerContext, SignedContext[] calldata signedContexts)
        external
        payable
        returns (FlowERC20IO calldata);
}
