use ethers::{
    abi::Token,
    contract::ContractFactory,
    core::k256::ecdsa::SigningKey,
    prelude::SignerMiddleware,
    providers::Middleware,
    signers::{Signer, Wallet},
    types::{Address, H160},
};
use once_cell::sync::Lazy;
use std::fs::File;
use std::io::{BufReader, Read};
use std::sync::Arc;
use tokio::sync::OnceCell;

use crate::{
    generated::{CLONEFACTORY_ABI, CLONEFACTORY_BYTECODE},
    utils::{setup::get_provider, utils::get_wallet},
};

static CLONE_FACTORY: Lazy<OnceCell<H160>> = Lazy::new(|| OnceCell::new());

#[derive(thiserror::Error, Debug)]
pub enum CloneFactoryError {
    #[error("An error when deploying CloneFactory")]
    DeployError(#[from] Box<dyn std::error::Error>),
}

async fn deploy_clone_factory(
    wallet: Option<Wallet<SigningKey>>,
    deployer: Address,
) -> anyhow::Result<H160, CloneFactoryError> {
    let wallet = wallet.unwrap_or(get_wallet(0));
    let provider = get_provider().await.expect("cannot get provider");
    let chain_id = provider.get_chainid().await.expect("cannot get chain id");

    let client = Arc::new(SignerMiddleware::new(
        provider.clone(),
        wallet.with_chain_id(chain_id.as_u64()),
    ));

    let f = File::open("tests/utils/deploy/clone_factory/CloneFactory.rain.meta")
        .expect("meta file not found");
    let mut reader = BufReader::new(f);
    let mut buffer = Vec::new();

    // Read file into vector.
    reader.read_to_end(&mut buffer).expect("cannot read file");

    let arg = vec![Token::Tuple(vec![
        Token::Address(deployer),
        Token::Bytes(buffer),
    ])];

    let deploy_transaction = ContractFactory::new(
        CLONEFACTORY_ABI.clone(),
        CLONEFACTORY_BYTECODE.clone(),
        client.clone(),
    );

    let clone_factory = deploy_transaction
        .deploy_tokens(arg)
        .expect("failed to deploy tokens")
        .send()
        .await
        .expect("failed at deployment");

    Ok(clone_factory.address())
}

pub async fn get_clone_factory_address(
    deployer: Address,
) -> Result<&'static H160, CloneFactoryError> {
    CLONE_FACTORY
        .get_or_try_init(|| async { deploy_clone_factory(None, deployer).await })
        .await
        .map_err(|e| CloneFactoryError::DeployError(Box::new(e)))
}
