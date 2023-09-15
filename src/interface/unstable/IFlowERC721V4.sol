// SPDX-License-Identifier: CAL
pragma solidity ^0.8.18;

import "rain.interpreter/src/interface/IInterpreterCallerV2.sol";
import "rain.interpreter/src/lib/caller/LibEvaluable.sol";

import {FlowERC721IOV1, ERC721SupplyChange} from "../IFlowERC721V3.sol";

import {RAIN_FLOW_SENTINEL} from "./IFlowV4.sol";

/// Constructor config.
/// @param name As per Open Zeppelin `ERC721Upgradeable`.
/// @param symbol As per Open Zeppelin `ERC721Upgradeable`.
/// @param baseURI As per Open Zeppelin `ERC721Upgradeable`.
/// @param evaluableConfig Constructor config for the `Evaluable` that defines
/// the mints/burn schedule.
/// @param flowConfig Constructor config for the `Evaluable` that defines the
/// flow behaviours outside self mints/burns.
struct FlowERC721ConfigV2 {
    string name;
    string symbol;
    string baseURI;
    EvaluableConfigV2 evaluableConfig;
    EvaluableConfigV2[] flowConfig;
}

/// @title IFlowERC721V4
interface IFlowERC721V4 {
    /// Contract has initialized.
    /// @param sender `msg.sender` initializing the contract (factory).
    /// @param config All initialized config.
    event Initialize(address sender, FlowERC721ConfigV2 config);

    function previewFlow(
        Evaluable calldata evaluable,
        uint256[] calldata callerContext,
        SignedContextV1[] calldata signedContexts
    ) external view returns (FlowERC721IOV1 calldata);

    function flow(
        Evaluable calldata evaluable,
        uint256[] calldata callerContext,
        SignedContextV1[] calldata signedContexts
    ) external returns (FlowERC721IOV1 calldata);
}
