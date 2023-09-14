use anyhow::Ok;
use ethers::prelude::SignerMiddleware;
use ethers::providers::Http;
use ethers::types::H160;
use ethers::{
    prelude::abigen,
    providers::Provider,
    signers::{LocalWallet, Signer},
    utils::AnvilInstance,
};

use std::sync::Arc;
use std::time::Duration;

abigen!(
    RainterpreterNP,
    "tests/utils/deploy/touch_deployer/RainterpreterNP.json";

    RainterpreterStore,
    "tests/utils/deploy/touch_deployer/RainterpreterStore.json"
);
pub async fn deploy_touch_deployer(anvil: &AnvilInstance) -> anyhow::Result<H160> {
    let provider =
        Provider::<Http>::try_from("http://localhost:8545")?.interval(Duration::from_millis(10u64));

    let interpreter = rainterpreter_deploy(&provider, &anvil).await?;
    let store = rainterpreter_store_deploy(&provider, &anvil).await?;
    println!("interpreter: {:?}", interpreter);
    println!("store: {:?}", store);
    let expression_deployer = rainterpreter_expression_deployer_deploy().await?;
    Ok(expression_deployer)
}

pub async fn rainterpreter_deploy(
    provider: &Provider<Http>,
    anvil: &AnvilInstance,
) -> anyhow::Result<H160> {
    let deployer: LocalWallet = anvil.keys()[0].clone().into();

    let deployer = Arc::new(SignerMiddleware::new(
        provider.clone(),
        deployer.with_chain_id(anvil.chain_id()),
    ));
    let store = RainterpreterNP::deploy(deployer, ())?.send().await?;
    Ok(store.address())
}

pub async fn rainterpreter_store_deploy(
    provider: &Provider<Http>,
    anvil: &AnvilInstance,
) -> anyhow::Result<H160> {
    let deployer: LocalWallet = anvil.keys()[0].clone().into();

    let deployer = Arc::new(SignerMiddleware::new(
        provider.clone(),
        deployer.with_chain_id(anvil.chain_id()),
    ));
    let store = RainterpreterStore::deploy(deployer, ())?.send().await?;
    Ok(store.address())
}

pub async fn rainterpreter_expression_deployer_deploy() -> anyhow::Result<H160> {
    let command =
        "npx hardhat run scripts/deployExpressionDeployer.ts --network localhost --no-compile";
    let _output = std::process::Command::new("sh")
        .arg("-c")
        .arg(command)
        .output()
        .expect("failed to execute hardhat script");

    println!("output: {:?}", String::from_utf8_lossy(&_output.stdout));

    return Ok(H160::zero());
}
