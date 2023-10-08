mod generated;
mod utils;

use utils::{
    deploy::{
        clone_factory::get_clone_factory_address,
        flow::deploy_flow,
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
    // Deploy expression deployer
    let expression_deployer = deploy_touch_deployer(None)
        .await
        .expect("cannot deploy expression_deployer");

    let _flow = deploy_flow(None, expression_deployer.address()).await?;

    let _ = is_sugraph_node_init()
        .await
        .expect("cannot check subgraph node");

    Ok(())
}
