// SPDX-License-Identifier: CAL
pragma solidity =0.8.19;

import "forge-std/Script.sol";
import "rain.interpreter/src/concrete/RainterpreterStore.sol";
import "rain.interpreter/src/concrete/RainterpreterNP.sol";
import "rain.interpreter/src/concrete/RainterpreterExpressionDeployerNP.sol";
import {LibAllStandardOpsNP} from "rain.interpreter/src/lib/op/LibAllStandardOpsNP.sol";


/// @title DeployDISPair
/// @notice A script that deploys a DeployDISPair.
/// This is intended to be run on every commit by CI to a testnet such as mumbai,
/// then cross chain deployed to whatever mainnet is required, by users.
contract DeployDISPair is Script {
    function run() external {
        bytes memory authoringMeta = vm.readFileBinary("meta/RainterpreterExpressionDeployerNP.rain.meta");
        uint256 deployerPrivateKey = vm.envUint("DEPLOYMENT_KEY");
        vm.startBroadcast(deployerPrivateKey);
        RainterpreterNP interpreter = new RainterpreterNP();
        RainterpreterStore store = new RainterpreterStore();
        RainterpreterExpressionDeployerNP deployer =
        new RainterpreterExpressionDeployerNP(RainterpreterExpressionDeployerConstructionConfig(
            address(interpreter),
            address(store),
            authoringMeta
        ));
        (deployer);
        vm.stopBroadcast();

        console2.log("interpreter");
        console2.logAddress(address(interpreter));
        console2.log("store");
        console2.logAddress(address(store));
        console2.log("deployer");
        console2.logAddress(address(deployer));
    }
}

