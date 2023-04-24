// SPDX-License-Identifier: CAL
pragma solidity ^0.8.18;

import "rain.interface.interpreter/IInterpreterCallerV2.sol";
import "rain.interface.interpreter/LibEvaluable.sol";

struct FlowConfig {
    // https://github.com/ethereum/solidity/issues/13597
    EvaluableConfig dummyConfig;
    EvaluableConfig[] config;
}

struct NativeTransfer {
    address from;
    address to;
    uint256 amount;
}

struct ERC20Transfer {
    address token;
    address from;
    address to;
    uint256 amount;
}

struct ERC721Transfer {
    address token;
    address from;
    address to;
    uint256 id;
}

struct ERC1155Transfer {
    address token;
    address from;
    address to;
    uint256 id;
    uint256 amount;
}

struct FlowTransfer {
    /// WARNING: Native transfers were deprecated due to incompatibilities with
    /// the multicall pattern.
    /// https://samczsun.com/two-rights-might-make-a-wrong/
    NativeTransfer[] native;
    ERC20Transfer[] erc20;
    ERC721Transfer[] erc721;
    ERC1155Transfer[] erc1155;
}

interface IFlowV2 {
    event Initialize(address sender, FlowConfig config);

    function previewFlow(
        Evaluable calldata evaluable,
        uint256[] calldata callerContext,
        SignedContextV1[] calldata signedContexts
    ) external view returns (FlowTransfer calldata flowTransfer);

    function flow(
        Evaluable calldata evaluable,
        uint256[] calldata callerContext,
        SignedContextV1[] calldata signedContexts
    ) external payable returns (FlowTransfer calldata flowTransfer);
}
