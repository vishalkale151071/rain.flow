use std::{clone, sync::Arc};

use crate::{
    generated::{
        clone_factory::{self, CloneFactory},
        Flow,
    },
    utils::{setup::get_provider, utils::get_wallet},
};
use ethers::{
    core::k256::ecdsa::SigningKey,
    prelude::SignerMiddleware,
    providers::{Http, Middleware, Provider},
    signers::{Signer, Wallet},
    types::{Bytes, H160},
};

use super::clone_factory::get_clone_factory_address;

pub async fn deploy_flow(
    wallet: Option<Wallet<SigningKey>>,
    clone_factory: H160,
    deployer: H160,
    implementation: H160,
    data: Bytes,
) -> anyhow::Result<H160> {
    let wallet = Some(wallet.unwrap_or(get_wallet(0))).expect("cannot get wallet");
    let provider = get_provider().await.expect("cannot get provider");
    let chain_id = provider.get_chainid().await?;

    let client = Arc::new(SignerMiddleware::new(
        provider,
        wallet.with_chain_id(chain_id.as_u64()),
    ));
    let clone_factory = get_clone_factory_address(deployer)
        .await
        .expect("cannot get clone factory");

    let clone_factory = CloneFactory::new(*clone_factory, client.clone());

    let clone = clone_factory.clone(implementation, data);

    Ok(H160::zero())
}
