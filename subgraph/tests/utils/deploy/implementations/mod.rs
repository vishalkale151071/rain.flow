use std::fs::File;
use std::io::{BufReader, Read};
use std::sync::Arc;

use ethers::abi::Token;
use ethers::types::Address;
use ethers::{
    contract::ContractFactory, prelude::SignerMiddleware, providers::Middleware, signers::Signer,
    types::H160,
};
use once_cell::sync::Lazy;
use tokio::sync::OnceCell;

use crate::generated::{
    FLOWERC1155_ABI, FLOWERC1155_BYTECODE, FLOWERC20_ABI, FLOWERC20_BYTECODE, FLOWERC721_ABI,
    FLOWERC721_BYTECODE, FLOW_ABI, FLOW_BYTECODE,
};
use crate::utils::{setup::get_provider, utils::get_wallet};

static FLOW_IMPLEMENTATION: Lazy<OnceCell<H160>> = Lazy::new(|| OnceCell::new());
static FLOWERC20_IMPLEMENTATION: Lazy<OnceCell<H160>> = Lazy::new(|| OnceCell::new());
static FLOWERC721_IMPLEMENTATION: Lazy<OnceCell<H160>> = Lazy::new(|| OnceCell::new());
static FLOWERC1155_IMPLEMENTATION: Lazy<OnceCell<H160>> = Lazy::new(|| OnceCell::new());

#[derive(thiserror::Error, Debug)]
pub enum FlowImplementationError {
    #[error("An error when deploying Flow implementation")]
    DeployError(#[from] Box<dyn std::error::Error>),
}

#[derive(thiserror::Error, Debug)]
pub enum FlowERC20ImplementationError {
    #[error("An error when deploying FlowERC20 implementation")]
    DeployError(#[from] Box<dyn std::error::Error>),
}

#[derive(thiserror::Error, Debug)]
pub enum FlowERC721ImplementationError {
    #[error("An error when deploying FlowERC721 implementation")]
    DeployError(#[from] Box<dyn std::error::Error>),
}

#[derive(thiserror::Error, Debug)]
pub enum FlowERC1155ImplementationError {
    #[error("An error when deploying FlowERC1155 implementation")]
    DeployError(#[from] Box<dyn std::error::Error>),
}

async fn deploy_flow_implementation(
    deployer: Address,
) -> anyhow::Result<H160, FlowImplementationError> {
    let provider = get_provider().await.expect("cannot get provider");
    let wallet = get_wallet(0);

    let chain_id = provider.get_chainid().await.expect("cannot get chain id");

    let client = Arc::new(SignerMiddleware::new(
        provider.clone(),
        wallet.with_chain_id(chain_id.as_u64()),
    ));

    let deploy_transation =
        ContractFactory::new(FLOW_ABI.clone(), FLOW_BYTECODE.clone(), client.clone());

    let f = File::open("tests/utils/deploy/implementations/flowMetaDocument")
        .expect("meta file flowMetaDocument not found");

    let mut reader = BufReader::new(f);
    let mut buffer = Vec::new();

    // Read file into vector.
    reader
        .read_to_end(&mut buffer)
        .expect("cannot read file flowMetaDocument");

    let buffer = hex::decode(buffer).expect("cannot decode buffer");

    let arg = vec![Token::Tuple(vec![
        Token::Address(deployer),
        Token::Bytes(buffer),
    ])];

    let implementation = deploy_transation
        .deploy_tokens(arg)
        .expect("cannot deploy flow implementation")
        .send()
        .await
        .expect("cannot send flow implementation");

    Ok(implementation.address())
}

async fn deploy_flow20_implementation(
    deployer: Address,
) -> anyhow::Result<H160, FlowERC20ImplementationError> {
    let provider = get_provider().await.expect("cannot get provider");
    let wallet = get_wallet(0);

    let chain_id = provider.get_chainid().await.expect("cannot get chain id");

    let client = Arc::new(SignerMiddleware::new(
        provider.clone(),
        wallet.with_chain_id(chain_id.as_u64()),
    ));

    let deploy_transation = ContractFactory::new(
        FLOWERC20_ABI.clone(),
        FLOWERC20_BYTECODE.clone(),
        client.clone(),
    );

    let f = File::open("tests/utils/deploy/implementations/flow20MetaDocument")
        .expect("meta file not flow20MetaDocument found");

    let mut reader = BufReader::new(f);
    let mut buffer = Vec::new();

    // Read file into vector.
    reader
        .read_to_end(&mut buffer)
        .expect("cannot read file flow20MetaDocument");

    let buffer = hex::decode(buffer).expect("cannot decode buffer");

    let arg = vec![Token::Tuple(vec![
        Token::Address(deployer),
        Token::Bytes(buffer),
    ])];

    let implementation = deploy_transation
        .deploy_tokens(arg)
        .expect("cannot deploy flow20 implementation")
        .send()
        .await
        .expect("cannot send flow20 implementation");

    Ok(implementation.address())
}

async fn deploy_flow721_implementation(
    deployer: Address,
) -> anyhow::Result<H160, FlowERC721ImplementationError> {
    let provider = get_provider().await.expect("cannot get provider");
    let wallet = get_wallet(0);

    let chain_id = provider.get_chainid().await.expect("cannot get chain id");

    let client = Arc::new(SignerMiddleware::new(
        provider.clone(),
        wallet.with_chain_id(chain_id.as_u64()),
    ));

    let deploy_transation = ContractFactory::new(
        FLOWERC721_ABI.clone(),
        FLOWERC721_BYTECODE.clone(),
        client.clone(),
    );

    let f = File::open("tests/utils/deploy/implementations/flow721MetaDocument")
        .expect("meta file flow721MetaDocument not found");

    let mut reader = BufReader::new(f);
    let mut buffer = Vec::new();

    // Read file into vector.
    reader
        .read_to_end(&mut buffer)
        .expect("cannot read file flow721MetaDocument");

    let buffer = hex::decode(buffer).expect("cannot decode buffer");

    let arg = vec![Token::Tuple(vec![
        Token::Address(deployer),
        Token::Bytes(buffer),
    ])];

    let implementation = deploy_transation
        .deploy_tokens(arg)
        .expect("cannot deploy flow721 implementation")
        .send()
        .await
        .expect("cannot send flow721 implementation");

    Ok(implementation.address())
}

async fn deploy_flow1155_implementation(
    deployer: Address,
) -> anyhow::Result<H160, FlowERC1155ImplementationError> {
    let provider = get_provider().await.expect("cannot get provider");
    let wallet = get_wallet(0);

    let chain_id = provider.get_chainid().await.expect("cannot get chain id");

    let client = Arc::new(SignerMiddleware::new(
        provider.clone(),
        wallet.with_chain_id(chain_id.as_u64()),
    ));

    let deploy_transation = ContractFactory::new(
        FLOWERC1155_ABI.clone(),
        FLOWERC1155_BYTECODE.clone(),
        client.clone(),
    );

    let f = File::open("tests/utils/deploy/implementations/flow1155MetaDocument")
        .expect("meta file flow1155MetaDocument not found");

    let mut reader = BufReader::new(f);
    let mut buffer = Vec::new();

    // Read file into vector.
    reader
        .read_to_end(&mut buffer)
        .expect("cannot read file flow1155MetaDocument");

    let buffer = hex::decode(buffer).expect("cannot decode buffer");

    let arg = vec![Token::Tuple(vec![
        Token::Address(deployer),
        Token::Bytes(buffer),
    ])];

    let implementation = deploy_transation
        .deploy_tokens(arg)
        .expect("cannot deploy flow1155 implementation")
        .send()
        .await
        .expect("cannot send flow1155 implementation");

    Ok(implementation.address())
}

pub async fn flow_implementation(
    deployer: Address,
) -> Result<&'static H160, FlowImplementationError> {
    FLOW_IMPLEMENTATION
        .get_or_try_init(|| async { deploy_flow_implementation(deployer).await })
        .await
        .map_err(|e| FlowImplementationError::DeployError(Box::new(e)))
}

pub async fn flow20_implementation(
    deployer: Address,
) -> Result<&'static H160, FlowERC20ImplementationError> {
    FLOWERC20_IMPLEMENTATION
        .get_or_try_init(|| async { deploy_flow20_implementation(deployer).await })
        .await
        .map_err(|e| FlowERC20ImplementationError::DeployError(Box::new(e)))
}

pub async fn flow721_implementation(
    deployer: Address,
) -> Result<&'static H160, FlowERC721ImplementationError> {
    FLOWERC721_IMPLEMENTATION
        .get_or_try_init(|| async { deploy_flow721_implementation(deployer).await })
        .await
        .map_err(|e| FlowERC721ImplementationError::DeployError(Box::new(e)))
}

pub async fn flow1155_implementation(
    deployer: Address,
) -> Result<&'static H160, FlowERC1155ImplementationError> {
    FLOWERC1155_IMPLEMENTATION
        .get_or_try_init(|| async { deploy_flow1155_implementation(deployer).await })
        .await
        .map_err(|e| FlowERC1155ImplementationError::DeployError(Box::new(e)))
}
