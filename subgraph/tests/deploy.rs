mod generated;
mod utils;

use utils::{
    deploy::{
        clone_factory::get_clone_factory_address,
        implementations::{
            flow1155_implementation, flow20_implementation, flow721_implementation,
            flow_implementation,
        },
        touch_deployer::deploy_touch_deployer,
    },
    setup::is_sugraph_node_init,
};

#[tokio::main]
#[test]
async fn flow_entity_test() -> anyhow::Result<()> {
    // Deploy
    let expression_deployer = deploy_touch_deployer(None)
        .await
        .expect("cannot deploy expression_deployer");

    // Deploy CloneFactory
    let clone_factory = get_clone_factory_address(expression_deployer.address())
        .await
        .expect("cannot deploy clone_factory");

    println!("clone_factory: {:?}", clone_factory);

    let flow_implementation_ = flow_implementation(expression_deployer.address().clone())
        .await
        .expect("cannot deploy flow_implementation");

    let _ = is_sugraph_node_init()
        .await
        .expect("cannot check subgraph node");

    Ok(())
}
