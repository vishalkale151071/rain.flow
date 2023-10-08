use std::{
    fs::File,
    io::{BufReader, Read},
    sync::Arc,
};

use crate::{
    generated::clone_factory::CloneFactory,
    utils::{setup::get_provider, utils::get_wallet},
};
use ethers::{
    core::k256::ecdsa::SigningKey,
    prelude::SignerMiddleware,
    providers::{Http, Middleware, Provider},
    signers::{Signer, Wallet},
    types::{Address, Bytes, H160},
};

use super::{clone_factory::get_clone_factory_address, implementations::flow20_implementation};

pub async fn deploy_flow(
    wallet: Option<Wallet<SigningKey>>,
    deployer: H160,
) -> anyhow::Result<H160> {
    let wallet = Some(wallet.unwrap_or(get_wallet(0))).expect("cannot get wallet");
    let provider = get_provider().await.expect("cannot get provider");
    let chain_id = provider.get_chainid().await?;

    let implementation = flow20_implementation(deployer)
        .await
        .expect("cannot get implementation");

    let client = Arc::new(SignerMiddleware::new(
        provider,
        wallet.with_chain_id(chain_id.as_u64()),
    ));
    let clone_factory = get_clone_factory_address(deployer)
        .await
        .expect("cannot get clone factory");

    let f = File::open("tests/utils/deploy/flow/flow_config_demo").expect("cannot open file");
    let mut reader = BufReader::new(f);
    let mut buffer = Vec::new();

    // Read file into vector.
    reader.read_to_end(&mut buffer).expect("cannot read file");

    let buffer = hex::decode(buffer).expect("cannot decode buffer");

    println!("buffer: {:?}", buffer);

    let clone_factory = CloneFactory::new(*clone_factory, client.clone());

    let clone = clone_factory.clone(*implementation, buffer.into()).await?;
    println!("clone: {:?}", clone);

    Ok(H160::zero())
}
