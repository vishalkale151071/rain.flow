// SDPX-License-Identifier: CAL

pragma solidity =0.8.19;

import "forge-std/Script.sol";
import "src/concrete/erc721/FlowERC721.sol";

contract Implementation is Script {
    function run(bytes memory meta) public {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYMENT_KEY");
        vm.startBroadcast(deployerPrivateKey);
        DeployerDiscoverableMetaV2ConstructionConfig memory config;
        config.deployer = 0xFe7735A11e5BDEd847176aC05B428Ac3A654bb7E;
        config.meta = meta;

        console2.log("meta");
        console2.logBytes32(keccak256(meta));

        FlowERC721 flow = new FlowERC721(config);

        console2.log("flow");
        console2.logAddress(address(flow));
    }
}
