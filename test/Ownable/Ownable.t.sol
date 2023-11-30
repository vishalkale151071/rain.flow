// SPDX-License-Identifier: CAL

pragma solidity =0.8.19;
import "forge-std/Test.sol";
import "rain.factory/src/interface/ICloneableFactoryV2.sol";
import "src/concrete/erc721/FlowERC721.sol";
import "rain.interpreter/src/interface/unstable/IParserV1.sol";
import "src/interface/unstable/IFlowERC721V4.sol";
contract OwnableTest is Test {
    address owner = makeAddr("owner");
    
    IOwnable flow;

    function setUp() public {
        string memory mumbaiRPCURL = "https://rpc.ankr.com/polygon_mumbai";
        uint256 fork = vm.createFork(mumbaiRPCURL);
        vm.selectFork(fork);
        vm.rollFork(43013398);

        address deployer = 0xFe7735A11e5BDEd847176aC05B428Ac3A654bb7E;
        bytes memory EXPRESSION = 
            "sentinel: 115183058774379759847873638693462432260838474092724525396123647190314935293775;"
        ;

        (bytes memory bytecode, uint256[] memory constants) = IParserV1(deployer).parse(EXPRESSION);

        EvaluableConfigV2 memory evaluableConfig;
        evaluableConfig.bytecode = bytecode;
        evaluableConfig.constants = constants;
        evaluableConfig.deployer = IExpressionDeployerV2(deployer);

        FlowERC721ConfigV2 memory config;
        config.name = "Test";
        config.symbol = "TEST";
        config.baseURI = "https://example.com/";
        config.owner = owner;
        config.evaluableConfig = evaluableConfig;
        EvaluableConfigV2[] memory flowConfig = new EvaluableConfigV2[](1);
        flowConfig[0] = evaluableConfig;

        

        ICloneableFactoryV2 factory = ICloneableFactoryV2(0xAB69D80Cc48763a6EaF38Fd68bE3933782D45507);
        address clone = factory.clone(0xd163C73E53679c656375E4ABA2B8959AaDe6Ebc4, abi.encode(config));
        flow = IOwnable(clone);
    }

    function test_Owner() public {
        assertEq(flow.owner(), owner);
    }

    function test_TransferOwnership() public {
        address newOwner = makeAddr("newOwner");
        vm.startPrank(owner);
        flow.transferOwnership(newOwner);
        assertEq(flow.owner(), newOwner);
    }

    function test_revertTransferOwnershipToZeroAddress() public {
        vm.startPrank(owner);
        vm.expectRevert("Ownable: new owner is the zero address");
        flow.transferOwnership(address(0));

        assertEq(flow.owner(), owner);
    }

    function test_revertTransferOwnershipByNonOwner() public {
        address notOwner = makeAddr("notOwner");
        vm.startPrank(notOwner);
        vm.expectRevert("Ownable: caller is not the owner");
        flow.transferOwnership(owner);

        assertEq(flow.owner(), owner);
    }
}

interface IOwnable {
    function owner() external view returns (address);
    function transferOwnership(address newOwner) external;
}